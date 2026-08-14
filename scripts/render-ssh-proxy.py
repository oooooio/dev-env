#!/usr/bin/env python3
"""sing-box SSH 代理渲染器 (运行期工具)。

镜像不内置任何代理 outbound (无模板); 容器启动时设置了 SSH_PROXY_SERVER 和
SSH_PROXY_PASSWORD 时, 本脚本把 SSH outbound 注入基础配置并指向它,
写入 /etc/sing-box/config.runtime.json 供 sing-box 使用。

环境变量:
  SSH_PROXY_SERVER   SSH 服务器地址 (与 SSH_PROXY_PASSWORD 同时设置才启用)
  SSH_PROXY_PORT     SSH 端口 (默认 22)
  SSH_PROXY_USER     登录用户 (默认 root)
  SSH_PROXY_PASSWORD SSH 密码 (必填)
"""
import json
import os
import sys

BASE_CONFIG = "/etc/sing-box/config.json"
RUNTIME_CONFIG = "/etc/sing-box/config.runtime.json"

server = os.environ.get("SSH_PROXY_SERVER", "").strip()
password = os.environ.get("SSH_PROXY_PASSWORD", "").strip()
port = int(os.environ.get("SSH_PROXY_PORT", "22") or 22)
user = os.environ.get("SSH_PROXY_USER", "root") or "root"

if not server:
    if password:
        print("WARN: SSH_PROXY_PASSWORD ignored (SSH_PROXY_SERVER not set)", file=sys.stderr)
    sys.exit(0)  # 未启用

if not password:
    print("WARN: SSH_PROXY_SERVER set but SSH_PROXY_PASSWORD not set; SSH proxy not enabled",
          file=sys.stderr)
    sys.exit(1)  # 未渲染, 通知调用方

outbound = {
    "type": "ssh",
    "tag": "proxy",
    "server": server,
    "server_port": port,
    "user": user,
    "password": password,
}

try:
    with open(BASE_CONFIG) as f:
        config = json.load(f)
except OSError as e:
    print("ERROR: cannot read %s: %s" % (BASE_CONFIG, e), file=sys.stderr)
    sys.exit(1)

# 基础配置无 proxy outbound; 动态添加 SSH outbound 并让路由指向它
config.setdefault("outbounds", []).append(outbound)
config["route"]["final"] = "proxy"

with open(RUNTIME_CONFIG, "w") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print("SSH proxy enabled: %s@%s:%d (password auth)" % (user, server, port))
