# ============================================================
# 版本设置（要升级版本，只改下面这几行；改法见操作说明）
# ============================================================
ARG NODE_MAJOR=24

FROM node:${NODE_MAJOR}-slim

ARG XRAY_VERSION=v26.3.27
ARG XRAY_SHA256=23cd9af937744d97776ee35ecad4972cf4b2109d1e0fe6be9930467608f7c8ae
ARG TTYD_VERSION=1.7.7
ARG TTYD_SHA256=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55

# 只装需要的：unzip（必须）、tmux（保持会话）、tini（做 PID 1）。
# curl 仅用于构建时下载，装完立即卸载。
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends unzip tmux tini ca-certificates curl; \
    \
    curl -fsSL -o /tmp/xray.zip \
      "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip"; \
    echo "${XRAY_SHA256}  /tmp/xray.zip" | sha256sum -c -; \
    mkdir -p /usr/local/share/xray; \
    unzip -o /tmp/xray.zip xray geoip.dat geosite.dat -d /tmp/xray; \
    install -m 0755 /tmp/xray/xray /usr/local/bin/xray; \
    install -m 0644 /tmp/xray/geoip.dat /tmp/xray/geosite.dat /usr/local/share/xray/; \
    \
    curl -fsSL -o /usr/local/bin/ttyd \
      "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64"; \
    echo "${TTYD_SHA256}  /usr/local/bin/ttyd" | sha256sum -c -; \
    chmod 0755 /usr/local/bin/ttyd; \
    \
    apt-get purge -y --auto-remove curl; \
    rm -rf /var/lib/apt/lists/* /tmp/xray /tmp/xray.zip

COPY start.sh gen-config.js xray-config.template.json /app/
RUN chmod 0755 /app/start.sh

ENV XRAY_LOCATION_ASSET=/usr/local/share/xray
USER node
WORKDIR /home/node

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/start.sh"]
