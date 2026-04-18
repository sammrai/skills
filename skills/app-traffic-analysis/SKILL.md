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

Create a working directory in the project (e.g. `<project>/mitmproxy/`) and run the upstream image directly — no compose file needed.

```bash
mkdir -p <project>/mitmproxy/captures
cd <project>/mitmproxy

docker run -d --name mitmproxy --restart unless-stopped \
  -p 8080:8080 -p 8081:8081 \
  -v "$PWD/captures:/captures" \
  mitmproxy/mitmproxy:latest \
  mitmweb --web-host 0.0.0.0 --set connection_strategy=lazy --ssl-insecure \
          --set web_open_browser=false -w /captures/flows.mitm

hostname -I | awk '{print $1}'   # note LAN IP for device proxy
```

The device fetches the CA via `http://mitm.it` through the proxy, so there is no need to mount `mitmproxy-data/` to the host. If the container is recreated, the CA regenerates and all trusting devices must re-install it — mount `mitmproxy-data` only when that tradeoff matters.

Web UI: `http://localhost:8081`.

## Step 2: Device Configuration

### iOS 13+

1. Same Wi-Fi as host. Wi-Fi → Manual proxy → `<host IP>:8080`
2. Open **Safari** → `http://mitm.it` → download iOS profile
3. **Settings > General > VPN & Device Management** → install profile
4. **Settings > General > About > Certificate Trust Settings** → toggle mitmproxy **ON** (required, easy to miss)

### Android 7+

User CAs are not trusted by apps by default. Either:
- Use an Android Studio AVD with writable system partition, place CA in `/system/etc/security/cacerts/`
- Run `apk-mitm <target>.apk` to patch the APK, then sideload

Verify with `https://example.com` in the device browser — a decrypted `200 OK` in mitmweb confirms setup.

## Step 3: Capture

Launch the target app on the device and exercise every feature relevant to the API surface being documented (search, detail views, notifications, list pagination, etc.). Each screen/action typically triggers API calls. Let `captures/flows.mitm` accumulate.

## Step 4: Generate openapi.yaml

Pull the pre-built image once, then run the two-pass workflow. The fork at `ghcr.io/sammrai/mitmproxy2swagger:xml` adds XML response schema inference on top of upstream's JSON and msgpack support; JSON-only APIs work equally well with this image.

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

After pass 2, `openapi.yaml` contains paths, query parameter types, and response schemas for JSON, msgpack, and XML payloads.

## Cert Pinning

If the target app's API host consistently produces `Client TLS handshake failed` in `docker logs mitmproxy`, the app has certificate pinning. Handling, in order of effort:

1. Try an older version of the app (often unpinned)
2. Rooted/jailbroken device + `objection -g <id> explore` → `ios sslpinning disable` / `android sslpinning disable`
3. `apk-mitm` on Android (handles OkHttp CertificatePinner)

Pinning failures against Apple/Google infrastructure domains (iCloud, gstatic) are normal and can be ignored.

## Legal Note

This workflow assumes the target app is one's own, or that reverse engineering is permitted under the target service's ToS or a security-research context. Captured APIs should not be used against third-party services in production in ways that violate ToS — prefer official APIs, public feeds, or HTML scraping of public pages for production data pipelines.
