# Docker 开发环境

基于 Debian 13 的精简 Docker 开发环境，内置 Python (uv) 和 Node.js (fnm) 工具链、SSH 远程访问、sing-box 代理客户端与 SSH 代理支持。

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
- 基础工具：curl、git、vim、tmux、ripgrep、unzip、sudo、[direnv](https://direnv.net)（进入目录自动加载 `.envrc`，容器内已配置自动 `direnv allow`）
- Python：系统 python3 + [uv](https://astral.sh/uv)（极速 Python 包管理器和运行器，系统级安装）
- Node.js：[fnm](https://github.com/Schniz/fnm) + 最新 LTS 版本，含 npm 全局包 `opencode-ai`、`@anthropic-ai/claude-code`
- [rtk](https://github.com/rtk-ai/rtk) - Rust Token Killer，系统级安装
- [sing-box](https://github.com/SagerNet/sing-box) - 可手动配置的代理客户端（默认不启用 inbound/TUN）
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

镜像内置 sing-box，但默认不配置任何 inbound，因此不会创建 TUN 网卡，也不会自动接管容器流量。基础配置位于：

```text
/etc/sing-box/config.json
```

当前配置仅保留 direct/block outbound。需要手动使用 SSH outbound 时，执行独立脚本生成运行时配置：

```bash
# 密码认证（脚本会交互式读取密码）
sudo /usr/local/bin/render-ssh-proxy.sh \
  proxy.example.com 22 ubuntu

# 私钥认证
sudo /usr/local/bin/render-ssh-proxy.sh \
  proxy.example.com 22 ubuntu /home/developer/.ssh/proxy_key
```

脚本生成：

```text
/etc/sing-box/config.runtime.json
```

然后手动校验并启动：

```bash
sudo sing-box check -c /etc/sing-box/config.runtime.json
sudo sing-box run -c /etc/sing-box/config.runtime.json
```

> 关闭 TUN 后，sing-box 没有 inbound，不会主动接收容器流量。若要让应用通过代理，必须另外配置 inbound，或在配置中加入其他流量接入方式。

### 修改 sing-box 配置

编辑 `configs/sing-box/config.json` 后重新构建镜像；也可以运行时挂载覆盖：

```bash
docker build -t dev-env .
docker run --rm -it \
  -v ./configs/sing-box/config.json:/etc/sing-box/config.json:ro \
  dev-env
```

### 验证配置与进程

```bash
sudo sing-box check -c /etc/sing-box/config.json
ps -eo pid,user,args | grep '[s]ing-box'
```

sing-box 不再由容器启动命令自动启动；日志由手动启动命令决定，例如：

```bash
sudo nohup sing-box run \
  -c /etc/sing-box/config.runtime.json \
  >/var/log/sing-box.log 2>&1 &
tail -f /var/log/sing-box.log
```

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

修改 `Dockerfile` 添加更多工具；所有下载均走官方源直连。

## 镜像仓库

- GitHub: https://github.com/zhai-research/dev-env
