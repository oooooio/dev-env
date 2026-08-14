# Docker 开发环境

基于 Debian 13 的精简 Docker 开发环境，内置 Python (uv) 和 Node.js (fnm) 工具链、SSH 远程访问，以及针对国内网络的镜像源配置。

## 使用说明

### 本地构建和运行

```bash
# 构建镜像
docker build -t dev-env .

# 运行容器
docker run --rm -it dev-env

# 运行并挂载当前目录
docker run --rm -it -v $(pwd):/workspace -w /workspace dev-env
```

### 使用 Docker Compose

```bash
# 启动
docker-compose up -d

# 进入容器
docker-compose exec dev-env bash

# 停止
docker-compose down
```

## 包含的内容

- Debian 13 (trixie)
- 基础工具：curl、git、vim、tmux、ripgrep、unzip、sudo
- Python：系统 python3 + [uv](https://astral.sh/uv)（极速 Python 包管理器和运行器，系统级安装）
- Node.js：[fnm](https://github.com/Schniz/fnm) + Node 24，含 npm 全局包 `opencode-ai`、`@anthropic-ai/claude-code`
- [rtk](https://github.com/rtk-ai/rtk) - Rust Token Killer，系统级安装
- [sing-box](https://github.com/SagerNet/sing-box) - 代理客户端（TUN 全局代理 + SOCKS5/HTTP 端口代理）
- SSH 服务：仅密钥登录，禁用 root，端口 22

## SSH 连接

容器内预置了 SSH 公钥（`/home/developer/.ssh/authorized_keys`），启动后可从宿主机直连：

```bash
# 容器内 SSH（默认端口 22）
ssh developer@<容器IP>

# 通过 docker-compose（映射宿主机 2222 端口）
ssh -p 2222 developer@localhost
```

SSH 配置：`PermitRootLogin no`、`PasswordAuthentication no`，仅允许密钥登录。默认用户 `developer` 免密 sudo。

## sing-box 代理客户端

镜像内置 sing-box 客户端，支持两种模式（可同时开启），并内置**国内直连 / 国外代理分流**：

- **TUN 全局透明代理**：容器内所有流量（git、apt、pip、claude 等）自动分流，无需逐工具配置。需要 `NET_ADMIN` 权限和 `/dev/net/tun` 设备（compose 已配置好）。
- **SOCKS5 / HTTP 端口代理**：容器内 `127.0.0.1:1080`（SOCKS5）、`127.0.0.1:1081`（HTTP），已映射到宿主机同名端口，宿主机应用也能用。

### 分流规则

```
国内域名 (geosite-cn)    ──┐
国内 IP (geoip-cn)       ──┼──→ 直连
私有网段 (10/8, 172/12…)  ──┘
其余所有流量             ──────→ 代理
```

- 域名识别靠 TLS SNI / HTTP Host 嗅探（`sniff`），国内域名走 geosite-cn 规则集，直连不受代理影响
- DNS 由 sing-box 接管（`hijack-dns`），统一走 223.5.5.5 直连解析，不经过代理
- 规则集（geosite-cn / geoip-cn）首次启动从 gh-proxy 下载，之后缓存复用

### 用 SSH 服务器当代理（运行时环境变量）

sing-box 内置 SSH outbound——直接把 SSH 服务器当作代理通道（sing-box 自己建立 SSH 连接，无需单独跑 `ssh -D`）。**镜像不内置任何代理服务器信息**（公开镜像，任何人都能拉取），SSH 代理完全在运行时通过环境变量配置：

| 环境变量 | 说明 | 默认 |
|---|---|---|
| `SSH_PROXY_SERVER` | SSH 服务器地址（与密码**同时设置**才启用） | - |
| `SSH_PROXY_PASSWORD` | SSH 密码 | - |
| `SSH_PROXY_USER` | 登录用户 | root |
| `SSH_PROXY_PORT` | SSH 端口 | 22 |

```bash
docker run -d --name dev-env --cap-add=NET_ADMIN --device=/dev/net/tun \
  -p 2222:22 -p 1080:1080 -p 1081:1081 \
  -e SSH_PROXY_SERVER=my-server.com \
  -e SSH_PROXY_USER=ubuntu \
  -e SSH_PROXY_PASSWORD='你的密码' \
  ghcr.io/zhai-research/dev-env/base:latest
```

docker-compose：把变量写进项目目录 `.env`（compose 已透传；`.env` 已被 `.gitignore` 忽略，不会提交）：

```
# .env
SSH_PROXY_SERVER=my-server.com
SSH_PROXY_USER=ubuntu
SSH_PROXY_PASSWORD=你的密码
```

启动脚本检测到 server+password 都有值时，动态生成 SSH outbound（密码认证）注入配置，分流规则不变（国内直连、国外走 SSH 隧道）。**改服务器 = 改环境变量重启**；**未配置时不启动 sing-box**。

⚠️ 注意：

- `SSH_PROXY_SERVER` 和 `SSH_PROXY_PASSWORD` **必须同时有值**才启用；只有其一日志会告警（`WARN: SSH_PROXY_*`），代理不启用但容器照常运行
- 密码会出现在 `docker inspect` 和部署机 `.env` 里，仅限信任的宿主机使用（`.env` 不提交 git）
- SSH 主机校验默认关闭（`host_key` 未设置时接受任意主机密钥），生产环境建议在配置里固定 `host_key`

### 修改分流规则等基础配置

镜像的基础配置（inbounds、DNS、分流规则）在 `configs/sing-box/config.json`——**不含任何代理服务器信息**，SSH 代理由运行时渲染注入。要改分流规则：编辑该文件后 `docker build -t dev-env .` 重建；或运行时用 `-v ./configs/sing-box/config.json:/etc/sing-box/config.json` 挂载覆盖。不需要 TUN 时删除 `tun-in` inbound 即可。

### 验证

```bash
# 端口代理模式（国外站，应走代理）
curl -x http://127.0.0.1:1081 https://www.google.com -I

# TUN 模式（容器内直接访问，国内站应直连）
docker-compose exec dev-env curl https://www.baidu.com -I

# 容器内工具走代理
docker-compose exec dev-env bash
export HTTP_PROXY=http://127.0.0.1:1081 HTTPS_PROXY=http://127.0.0.1:1081
claude
```

⚠️ **本地测试注意（macOS + 宿主机代理）**：如果宿主机本身开了代理（如 sing-box TUN + fakeip），宿主机会拦截容器内所有 DNS 查询并返回虚拟 IP，导致容器内"直连"路径无法工作——这是宿主机环境造成的，不是配置问题；在真实 DNS 环境（VPS/服务器）分流正常。本地调试可把容器 outbound 指向宿主机代理（如 `socks5://host.docker.internal:1080`）走通全链路。

### 日志

sing-box 由启动脚本后台启动，日志输出到容器 stdout：

```bash
# 宿主机查看
docker-compose logs dev-env | grep -i sing-box
```

⚠️ 安全提示：socks/http inbound 监听 `0.0.0.0` 并映射到宿主机端口，局域网内其他设备也可访问。如仅在容器内使用，可把 listen 改为 `127.0.0.1`，或宿主机防火墙放行来源 IP。TUN 模式的问题排查：`strict_route: true` 在部分环境不兼容，可改为 `false`。

## 镜像源（国内网络优化）

- **APT**：清华镜像（tuna），镜像构建完成后自动切换
- **PyPI**：清华源（见 `configs/uv.toml`）
- **npm**：`registry.npmmirror.com`
- **GitHub**：git clone 自动走 `gh-proxy.com` 代理
- **HuggingFace**：`hf-mirror.com`（`HF_ENDPOINT`）
- **Node.js 发行版**：清华 nodejs 镜像（`FNM_NODE_DIST_MIRROR`）

## 使用 uv

```bash
# 创建虚拟环境
uv venv

# 安装包
uv pip install requests

# 运行 Python 脚本
uv run script.py

# 使用特定 Python 版本
uv python install 3.12
uv run --python 3.12 script.py
```

## 自定义

修改 `Dockerfile` 添加更多工具，或修改 `configs/uv.toml` 更改 uv 配置。

## 镜像仓库

- GitHub: https://github.com/zhai-research/dev-env
