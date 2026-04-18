FROM python:3.12-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir \
    "git+https://github.com/sammrai/mitmproxy2swagger.git@feat/xml-response-support"
WORKDIR /work
ENTRYPOINT ["mitmproxy2swagger"]
