#!/bin/bash
# 容器启动脚本：仅启动 sshd；sing-box 代理由 render-ssh-proxy.sh 手动配置和启动。

set -u

mkdir -p /var/run/sshd
/usr/sbin/sshd -D &
SSHD_PID=$!

# 收到停止信号时清理 sshd
trap 'kill "$SSHD_PID" 2>/dev/null; exit 0' TERM INT

wait "$SSHD_PID"