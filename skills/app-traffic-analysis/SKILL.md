---
name: app-traffic-analysis
description: This skill should be used when the user wants to "generate OpenAPI from app traffic", "openapi化して", "reverse engineer mobile app API to openapi.yaml", "mitmproxyでアプリのAPIをopenapi化", "スマホアプリのAPIを調査してopenapi.yamlにしたい", or needs to go from zero to an OpenAPI 3.0 spec by capturing a mobile app's HTTPS traffic. Covers mitmproxy setup, device CA installation, traffic capture, and automated openapi.yaml generation via mitmproxy2swagger.
---

# App API → OpenAPI Spec

End-to-end pipeline to produce `openapi.yaml` from a mobile app's HTTPS traffic.

## Pipeline

1. Scaffold mitmproxy + mitmproxy2swagger via docker
2. Route the target device through the proxy and install the CA
3. Capture traffic while exercising the target app
4. Run mitmproxy2swagger to produce `openapi.yaml`

## Step 1: Scaffold

Create `<project>/mitmproxy/` and place both `assets/docker-compose.yml` and `assets/mitmproxy2swagger.Dockerfile` inside. Edit `container_name` in the compose file per project.

```bash
cd <project>/mitmproxy
docker compose up -d
docker build -t m2s -f mitmproxy2swagger.Dockerfile .
hostname -I | awk '{print $1}'   # note LAN IP for device proxy
```

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

mitmproxy2swagger is inherently two-pass: pass 1 emits a draft where every detected path is prefixed `ignore:`; pass 2 materializes paths whose `ignore:` has been removed.

```bash
# Pass 1: draft
docker run --rm -v <project>/mitmproxy:/work m2s \
  -i /work/captures/flows.mitm -o /work/openapi.yaml -p https://<target-host> -f flow

# Un-ignore all templated {id} paths (keeps literal numeric duplicates ignored)
sed -i -E '/\{id\}/ s/^- ignore:/- /' <project>/mitmproxy/openapi.yaml

# Pass 2: materialize paths and query params (add `-e` to include response examples)
docker run --rm -v <project>/mitmproxy:/work m2s \
  -i /work/captures/flows.mitm -o /work/openapi.yaml -p https://<target-host> -f flow -s
```

After pass 2, `openapi.yaml` contains paths, query parameter types, and response schemas for JSON, msgpack, and XML payloads.

**Note on the Docker image:** `assets/mitmproxy2swagger.Dockerfile` installs the patched fork at `sammrai/mitmproxy2swagger@feat/xml-response-support`, which adds XML response schema inference on top of upstream. If upstream merges the patch, switch back to `pip install mitmproxy2swagger`.

## Cert Pinning

If the target app's API host consistently produces `Client TLS handshake failed` in `docker logs`, the app has certificate pinning. Handling, in order of effort:

1. Try an older version of the app (often unpinned)
2. Rooted/jailbroken device + `objection -g <id> explore` → `ios sslpinning disable` / `android sslpinning disable`
3. `apk-mitm` on Android (handles OkHttp CertificatePinner)

Pinning failures against Apple/Google infrastructure domains (iCloud, gstatic) are normal and can be ignored.

## Legal Note

This workflow assumes the target app is one's own, or that reverse engineering is permitted under the target service's ToS or a security-research context. Captured APIs should not be used against third-party services in production in ways that violate ToS — prefer official APIs, public feeds, or HTML scraping of public pages for production data pipelines.

## Assets

- `assets/docker-compose.yml` — mitmproxy service (edit `container_name` per project)
- `assets/mitmproxy2swagger.Dockerfile` — one-shot runner image for mitmproxy2swagger
