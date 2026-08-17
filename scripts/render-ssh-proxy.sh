#!/usr/bin/env bash
# 手动生成 sing-box SSH outbound 运行时配置。
#
# 密码认证:
#   render-ssh-proxy.sh SERVER [PORT] [USER]
# 私钥认证:
#   render-ssh-proxy.sh SERVER [PORT] [USER] PRIVATE_KEY_FILE

set -euo pipefail

BASE_CONFIG=/etc/sing-box/config.json
RUNTIME_CONFIG=/etc/sing-box/config.runtime.json

usage() {
    printf '用法:\n' >&2
    printf '  %s SERVER [PORT] [USER]\n' "$0" >&2
    printf '  %s SERVER [PORT] [USER] PRIVATE_KEY_FILE\n' "$0" >&2
    exit 2
}

[[ $# -ge 1 && $# -le 4 ]] || usage

server=$1
port=${2:-22}
user=${3:-root}
key_file=${4:-}

if [[ -z "$server" ]]; then
    echo "ERROR: SERVER 不能为空" >&2
    exit 1
fi
if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    echo "ERROR: PORT 必须是数字: $port" >&2
    exit 1
fi
port_number=$((10#$port))
if ((port_number < 1 || port_number > 65535)); then
    echo "ERROR: PORT 超出范围: $port" >&2
    exit 1
fi
if [[ ! -f "$BASE_CONFIG" ]]; then
    echo "ERROR: 找不到 $BASE_CONFIG" >&2
    exit 1
fi

# 私钥认证不需要输入密码；否则从终端安全地读取密码，不出现在命令历史中。
if [[ -n "$key_file" ]]; then
    if [[ ! -r "$key_file" ]]; then
        echo "ERROR: 私钥文件不可读: $key_file" >&2
        exit 1
    fi
    auth_args=(--rawfile private_key "$key_file")
    auth_filter='"private_key": $private_key'
else
    read -r -s -p "SSH password: " password
    printf '\n' >&2
    auth_args=(--arg password "$password")
    auth_filter='"password": $password'
fi

# jq 负责 JSON 转义，避免特殊字符破坏配置；同时移除旧的 proxy，保证重复执行幂等。
tmp_config="$(mktemp "${RUNTIME_CONFIG}.XXXXXX")"
trap 'rm -f "$tmp_config"' EXIT

jq \
    --arg server "$server" \
    --arg user "$user" \
    --argjson server_port "$port_number" \
    "${auth_args[@]}" \
    ".outbounds = ((.outbounds // [])
        | map(select(.tag != \"proxy\"))
        + [{
            \"type\": \"ssh\",
            \"tag\": \"proxy\",
            \"server\": \$server,
            \"server_port\": \$server_port,
            \"user\": \$user,
            $auth_filter
        }])
     | .route = (.route // {})
     | .route.final = \"proxy\"" \
    "$BASE_CONFIG" > "$tmp_config"

chmod 600 "$tmp_config"
mv -f "$tmp_config" "$RUNTIME_CONFIG"
trap - EXIT

if [[ -n "$key_file" ]]; then
    echo "SSH proxy config generated: ${user}@${server}:${port_number} (private-key auth)"
else
    echo "SSH proxy config generated: ${user}@${server}:${port_number} (password auth)"
fi
