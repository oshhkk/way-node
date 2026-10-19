#!/usr/bin/env bash
# 启动脚本：tini 是 PID 1，本脚本拉起网页终端和 Xray。
# 任何一个进程退出，整个容器就退出，由 Railway 的重启策略重新拉起。
# 只输出状态信息，不输出任何密码、密钥或 UUID。

log() { echo "[start] $*"; }

PORT="${PORT:-8080}"

# ---- 必填变量检查 ----
if [ -z "${TERMINAL_USER:-}" ] || [ -z "${TERMINAL_PASSWORD:-}" ]; then
  log "错误：TERMINAL_USER 或 TERMINAL_PASSWORD 未设置，拒绝启动"
  exit 1
fi
if [ "${#TERMINAL_PASSWORD}" -lt 16 ]; then
  log "错误：TERMINAL_PASSWORD 太短（至少 16 位），拒绝启动"
  exit 1
fi
case "${TERMINAL_USER}" in
  *:*) log "错误：TERMINAL_USER 不能含冒号"; exit 1 ;;
esac
if [ -z "${XRAY_PORT:-}" ]; then
  log "错误：XRAY_PORT 未设置，拒绝启动"
  exit 1
fi
if [ "${XRAY_PORT}" = "${PORT}" ]; then
  log "错误：XRAY_PORT 不能等于 PORT，拒绝启动"
  exit 1
fi

PIDS=()

# ---- Xray：变量齐全才启动 ----
if [ -n "${XRAY_UUID:-}" ] && [ -n "${REALITY_PRIVATE_KEY:-}" ] && [ -n "${REALITY_SHORT_ID:-}" ] \
   && [ -n "${REALITY_DEST:-}" ] && [ -n "${REALITY_SERVER_NAMES:-}" ]; then
  CONF="$(mktemp /tmp/xray.XXXXXX.json)"
  if ! node /app/gen-config.js "$CONF"; then
    log "错误：Xray 配置生成失败（见上一行提示）"
    exit 1
  fi
  xray run -config "$CONF" &
  PIDS+=($!)
  log "Xray 已启动，监听内部端口 ${XRAY_PORT}"
else
  log "Xray 变量不全，本次只启动网页终端（首次部署的正常状态）"
fi

# ---- 网页终端 ----
# -W 允许输入；-P 30 每 30 秒发一次心跳，避免 Railway 60 秒空闲断开
# -t rendererType=dom：不用 WebGL 渲染，避免部分浏览器显示成条纹乱码；fontSize 固定字号
# -d 0 关闭 ttyd 自身的日志：它默认会把账号密码的 base64 编码打印到日志里
ttyd -p "${PORT}" -d 0 -W -P 30 -t rendererType=dom -t fontSize=16 -c "${TERMINAL_USER}:${TERMINAL_PASSWORD}" \
  tmux new-session -A -s main &
PIDS+=($!)
log "网页终端已启动，监听 ${PORT}"

# ---- 任一进程退出，整个容器退出 ----
wait -n
CODE=$?
log "有进程退出（状态码 ${CODE}），容器将退出并由 Railway 重启"
kill "${PIDS[@]}" 2>/dev/null
exit "${CODE:-1}"
