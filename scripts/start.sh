#!/bin/bash
# 容器启动脚本：sshd 为主进程；配置了 SSH 代理 (SSH_PROXY_SERVER/PASSWORD) 时
# 渲染 sing-box 配置并启动，否则 sing-box 不启动 (镜像不内置任何代理配置)

set -u

mkdir -p /var/run/sshd
/usr/sbin/sshd -D &
SSHD_PID=$!

# SSH 代理: 渲染运行时配置 (服务器默认值可来自镜像烘焙 ENV, 密码必须运行时传入)
SING_BOX_CONFIG=""
if [ -n "${SSH_PROXY_SERVER:-}" ]; then
  python3 /usr/local/bin/render-ssh-proxy.py && SING_BOX_CONFIG=/etc/sing-box/config.runtime.json
elif [ -n "${SSH_PROXY_PASSWORD:-}" ]; then
  echo "WARN: SSH_PROXY_PASSWORD set but SSH_PROXY_SERVER not set; ignored" >&2
else
  echo "INFO: SSH proxy not configured (set SSH_PROXY_SERVER + SSH_PROXY_PASSWORD), sing-box disabled"
fi

SING_BOX_PID=""
if [ -n "$SING_BOX_CONFIG" ]; then
  if ! sing-box check -c "$SING_BOX_CONFIG"; then
    echo "WARN: sing-box config check failed, sing-box disabled" >&2
  else
    sing-box run -c "$SING_BOX_CONFIG" &
    SING_BOX_PID=$!
  fi
elif [ -z "${SSH_PROXY_SERVER:-}" ] && [ -z "${SSH_PROXY_PASSWORD:-}" ]; then
  echo "INFO: SSH proxy not configured (set SSH_PROXY_SERVER + SSH_PROXY_PASSWORD), sing-box disabled"
fi

# 收到停止信号时清理子进程
trap 'kill $SSHD_PID ${SING_BOX_PID:-} 2>/dev/null; exit 0' TERM INT

# sshd 退出则容器退出
wait $SSHD_PID
