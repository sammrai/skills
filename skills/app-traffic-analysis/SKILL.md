---
name: app-traffic-analysis
description: This skill should be used when the user wants to "generate OpenAPI from app traffic", "openapi化して", "reverse engineer mobile app API to openapi.yaml", "mitmproxyでアプリのAPIをopenapi化", "スマホアプリのAPIを調査してopenapi.yamlにしたい", or needs to go from zero to an OpenAPI 3.0 spec by capturing a mobile app's HTTPS traffic. Covers mitmproxy setup, device CA installation, traffic capture, and automated openapi.yaml generation via mitmproxy2swagger.
---

# App API → OpenAPI Spec

End-to-end pipeline to produce `openapi.yaml` from a mobile app's HTTPS traffic.

## Pipeline

1. Start mitmproxy to capture traffic
2. Route the target device through the proxy and install the CA
3. Exercise the target app while flows are recorded
4. Run mitmproxy2swagger against the capture to produce `openapi.yaml`

## Step 1: Start mitmproxy

From the project root, create a `captures/` directory and start the upstream image directly — no compose file needed. Mount `$HOME/.mitmproxy` so the CA **persists across container recreations and is shared by every project** — the device trusts one CA forever, no matter how often you restart or re-scope the container. Scope interception to the target host(s) with `--allow-hosts`; everything else is passed through untouched (see below for why this matters).

```bash
mkdir -p captures ~/.mitmproxy

TARGET_HOST='example\.com'   # regex; only these hosts are decrypted (e.g. 'livefans\.jp' or '(a\.jp|b\.com)')

docker run -d --name mitmproxy --restart unless-stopped \
  -p 8080:8080 -p 8081:8081 \
  -v "$PWD/captures:/captures" \
  -v "$HOME/.mitmproxy:/home/mitmproxy/.mitmproxy" \
  mitmproxy/mitmproxy:latest \
  mitmweb --web-host 0.0.0.0 --set connection_strategy=lazy --ssl-insecure \
          --set web_open_browser=false \
          --allow-hosts "$TARGET_HOST" \
          -w +/captures/flows.mitm

hostname -I | awk '{print $1}'   # note LAN IP for device proxy
```

`-w +/captures/flows.mitm` appends rather than truncating, so re-scoping the container keeps prior flows.

**Never commit the capture or the CA.** `captures/flows.mitm` is fully decrypted traffic (cookies, auth tokens, PII); `~/.mitmproxy/mitmproxy-ca.pem` and `.p12` hold the **CA private key** (anyone who gets it can impersonate any host to every device trusting this CA — and it cannot be revoked). Add to `.gitignore` before the first commit:

```bash
printf '\ncaptures/\n*.mitm\n' >> .gitignore   # CA already lives outside the repo in ~/.mitmproxy
```

### Why `--allow-hosts` is not optional

With a global device proxy, **every** app's traffic hits mitmproxy. Certificate-pinned apps (Twitter/X, Mercari, PayPay, iCloud, most native apps) reject the proxy cert and **retry in a tight loop — dozens of failed handshakes per second**. This floods mitmproxy, and iOS's own connectivity check (`captive.apple.com`) starts failing through the proxy, so **iOS declares "No Internet" and cuts even Safari**. The symptom is "it worked for a minute, then the whole device lost connectivity." Restricting interception to `--allow-hosts <target>` makes every other host pass through with its **real** certificate — pinned apps connect normally, no flood, Safari stays alive, and only the target host is decrypted.

Web UI: `http://localhost:8081`.

### Re-scoping to a new target

Just recreate the container with a new `TARGET_HOST` (same command). Because the CA is mounted from `~/.mitmproxy`, it is **unchanged** — no device re-install needed. (Re-installing is only ever required the first time, or if you delete `~/.mitmproxy`.)

## Step 2: Device Configuration

### iOS 13+

Do this **once per device** — the persistent CA (Step 1) means it survives every later container restart.

1. Same Wi-Fi as host. Wi-Fi → Manual proxy → `<host IP>:8080`
2. Open **Safari** → `http://mitm.it` → download iOS profile
3. **Settings > General > VPN & Device Management** → install profile
4. **Settings > General > About > Certificate Trust Settings** → toggle mitmproxy **ON** (required, easy to miss)

If Safari later warns "this server's certificate is invalid" for the target host, the device is trusting an **old** CA that no longer matches the container's. This happens only if `~/.mitmproxy` was deleted/regenerated. Delete the old profile (VPN & Device Management), reinstall from `http://mitm.it`, and re-toggle trust. Verify the installed CA matches with:

```bash
openssl x509 -in ~/.mitmproxy/mitmproxy-ca-cert.pem -noout -fingerprint -sha256
```

### Android 7+

User CAs are not trusted by apps by default. Either:
- Use an Android Studio AVD with writable system partition, place CA in `/system/etc/security/cacerts/`
- Run `apk-mitm <target>.apk` to patch the APK, then sideload

Verify with `https://example.com` in the device browser — a decrypted `200 OK` in mitmweb confirms setup.

## Step 3: Capture

Exercise every feature relevant to the API surface being documented (search, detail views, notifications, list pagination, etc.). Each screen/action typically triggers API calls. Let `captures/flows.mitm` accumulate.

**Native app vs. Safari.** On stock (non-jailbroken) iOS a certificate-pinned native app cannot be intercepted — its handshakes just fail (see Cert Pinning). Many targets expose the same data through their **website or web API**, which loads in Safari and *is* captured (Safari honors the trusted CA). Prefer the web surface when it exists: it is easier, avoids pinning entirely, and is the more defensible source for a production data pipeline. Set `TARGET_HOST` to the web/API host and browse it in Safari.

Confirm setup end-to-end: with `TARGET_HOST` set to the target, load it in the device browser and look for a decrypted `200 OK` in mitmweb (`http://localhost:8081`). Tally what actually landed before generating:

```bash
docker run --rm -v "$PWD/captures:/captures" mitmproxy/mitmproxy:latest \
  mitmdump -nr /captures/flows.mitm -q 2>/dev/null | awk '{print $2, $4}' | sort | uniq -c | sort -rn | head
```

## Step 4: Generate openapi.yaml

Pull the pre-built image once, then run the two-pass workflow from the project root (where `captures/` lives and `openapi.yaml` will be written). The fork at `ghcr.io/sammrai/mitmproxy2swagger:xml` adds XML response schema inference on top of upstream's JSON and msgpack support; JSON-only APIs work equally well with this image.

```bash
docker pull ghcr.io/sammrai/mitmproxy2swagger:xml

# Pass 1: draft with all endpoints prefixed `ignore:`
docker run --rm -v "$PWD:/work" ghcr.io/sammrai/mitmproxy2swagger:xml \
  -i /work/captures/flows.mitm -o /work/openapi.yaml -p https://<target-host> -f flow

# Un-ignore all templated {id} paths (keeps literal numeric duplicates ignored)
sed -i -E '/\{id\}/ s/^- ignore:/- /' openapi.yaml

# Pass 2: materialize paths, query params, response schemas (add `-e` for examples)
docker run --rm -v "$PWD:/work" ghcr.io/sammrai/mitmproxy2swagger:xml \
  -i /work/captures/flows.mitm -o /work/openapi.yaml -p https://<target-host> -f flow -s
```

After pass 2, `openapi.yaml` contains paths, query parameter types, and response schemas for JSON, msgpack, and XML payloads. The schema-only output is safe to share; `-e` embeds **real captured response bodies** as examples (potential PII/tokens), so review before committing an examples build.

## Cert Pinning

With `--allow-hosts` scoping (Step 1), handshake failures for **non-target** hosts (icloud, gstatic, other apps) are expected and harmless — those hosts pass through untouched. Pinning only matters when the **target** host itself consistently produces `Client TLS handshake failed ... does not trust the proxy's certificate` in `docker logs mitmproxy`.

First rule out a stale CA: a failure reading `does not trust the proxy's certificate` on a host that *should* be intercepted usually means the device trusts an old CA — reinstall it (Step 2) before assuming pinning. Genuine pinning survives a correct CA install. Handling, in order of effort:

1. **Use the web surface instead** (Step 3) — usually removes the need to defeat pinning at all
2. Try an older version of the app (often unpinned)
3. Rooted/jailbroken device + `objection -g <id> explore` → `ios sslpinning disable` / `android sslpinning disable`
4. `apk-mitm <target>.apk` on Android (handles OkHttp CertificatePinner), then sideload

## Legal Note

This workflow assumes the target app is one's own, or that reverse engineering is permitted under the target service's ToS or a security-research context. Captured APIs should not be used against third-party services in production in ways that violate ToS — prefer official APIs, public feeds, or HTML scraping of public pages for production data pipelines.
