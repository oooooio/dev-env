FROM debian:13

ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_NO_DEV=1 \
    UV_NO_EDITABLE=1 \
    UV_LINK_MODE=copy \
    UV_VENV_DIR=/venv \
    FNM_DIR=/home/developer/.local/share/fnm

ENV PATH="$FNM_DIR:$PATH"

# 安装基础依赖 (构建在 GitHub Actions 上进行, 走官方 apt 源最快)
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl direnv git jq vim tmux openssh-server python3 unzip ripgrep sudo \
    && rm -rf /var/lib/apt/lists/*

# 创建普通用户并授权 sudo
RUN useradd -m -s /bin/bash developer \
    && echo "developer ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/developer \
    && mkdir -p /home/developer/.ssh \
    && chmod 700 /home/developer/.ssh \
    && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCXQNggLyEZhjxf0CBOdXOK2DzgEa5AmoAMsEaAvR9G' > /home/developer/.ssh/authorized_keys \
    && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDPGn4blND4QhvGbXdD7EYo/PMi7hkVb1WsdFDxWQCf' >> /home/developer/.ssh/authorized_keys \
    && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBSfiYu7iqqMvoVmMqcqApM44osw44T6nKzF/LPg5uoh'>> /home/developer/.ssh/authorized_keys \
    && chmod 600 /home/developer/.ssh/authorized_keys \
    && chown -R developer:developer /home/developer/.ssh

# 安装 uv (系统级)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mkdir -p /usr/local/bin \
    && mv /root/.local/bin/uv /usr/local/bin/uv \
    && mv /root/.local/bin/uvx /usr/local/bin/uvx

# 安装 rtk (系统级, 按目标架构下载最新稳定版)
# GitHub 直连下载; 网络抖动用 --http1.1 + 重试兜底
RUN case "$(uname -m)" in \
      aarch64) RTK_ASSET=rtk-aarch64-unknown-linux-gnu ;; \
      *)       RTK_ASSET=rtk-x86_64-unknown-linux-musl ;; \
    esac \
    && curl -LsSf --retry 3 --retry-all-errors --http1.1 "https://github.com/rtk-ai/rtk/releases/latest/download/${RTK_ASSET}.tar.gz" \
    | tar xz -C /usr/local/bin

# 安装 sing-box (系统级, 按目标架构下载最新稳定版)
RUN SING_BOX_VERSION="$(curl -LsSf --retry 3 --retry-all-errors --http1.1 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" \
      | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))')" \
    && case "$(uname -m)" in \
      aarch64) SING_BOX_ARCH=arm64 ;; \
      *)       SING_BOX_ARCH=amd64 ;; \
    esac \
    && curl -LsSf --retry 3 --retry-all-errors --http1.1 "https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-linux-${SING_BOX_ARCH}.tar.gz" \
    | tar xz -C /tmp \
    && mv /tmp/sing-box-${SING_BOX_VERSION}-linux-${SING_BOX_ARCH}/sing-box /usr/local/bin/sing-box \
    && rm -rf /tmp/sing-box-${SING_BOX_VERSION}-linux-${SING_BOX_ARCH}

# 安装 fnm (系统级, 按目标架构下载最新稳定版)
RUN case "$(uname -m)" in \
      aarch64) FNM_ASSET=fnm-arm64 ;; \
      *)       FNM_ASSET=fnm-linux ;; \
    esac \
    && curl -LsSf --retry 3 --retry-all-errors --http1.1 "https://github.com/Schniz/fnm/releases/latest/download/${FNM_ASSET}.zip" -o /tmp/fnm.zip \
    && unzip -o /tmp/fnm.zip -d /usr/local/bin \
    && rm /tmp/fnm.zip

# 用户级工具 (node LTS, npm 全局包)
# 构建在 GitHub Actions 上进行, 从官方 registry 安装最快
USER developer

RUN eval "$(fnm env)" \
    && fnm install --lts \
    && fnm use lts-latest \
    && npm i -g --no-audit --no-fund opencode-ai @anthropic-ai/claude-code \
    && npm cache clean --force \
    && cat >> ~/.bashrc <<'EOF'
# fnm: 自动切换 node 版本
eval "$(fnm env --use-on-cd)"
# direnv: 自动加载 .envrc (docker exec / 非登录 shell)
eval "$(direnv hook bash)"
# 开发容器信任所有 .envrc, 进入目录或编辑 .envrc 后自动 allow, 无需手动执行
if ! command -v _direnv_auto_allow >/dev/null 2>&1; then
    _direnv_auto_allow() {
        [ -f .envrc ] && direnv allow >/dev/null 2>&1
    }
    cd() {
        builtin cd "$@" || return $?
        _direnv_auto_allow
    }
fi
if [[ "${PROMPT_COMMAND[*]:-}" != *"_direnv_auto_allow"* ]]; then
    PROMPT_COMMAND=(_direnv_auto_allow "${PROMPT_COMMAND[@]}")
fi
EOF

# 登录 shell 配置 (SSH 会话): .profile 只在登录 shell 读取, 且会被 /etc/profile 重置 PATH
RUN cat > ~/.profile <<'EOF'
# 登录 shell (SSH) 会被 /etc/profile 重置 PATH, 这里恢复 node 等路径
export PATH="/usr/local/node-bin:$FNM_DIR:$PATH"
eval "$(fnm env --use-on-cd)"
# direnv: 自动加载 .envrc (SSH 登录 shell)
eval "$(direnv hook bash)"
if ! command -v _direnv_auto_allow >/dev/null 2>&1; then
    _direnv_auto_allow() {
        [ -f .envrc ] && direnv allow >/dev/null 2>&1
    }
    cd() {
        builtin cd "$@" || return $?
        _direnv_auto_allow
    }
fi
if [[ "${PROMPT_COMMAND[*]:-}" != *"_direnv_auto_allow"* ]]; then
    PROMPT_COMMAND=(_direnv_auto_allow "${PROMPT_COMMAND[@]}")
fi
EOF

USER root

# 将 node 版本 bin 目录链接到稳定路径, 保证所有会话 (docker exec/SSH/脚本) 都能用 node
RUN ln -sfn "$(ls -d /home/developer/.local/share/fnm/node-versions/v*/installation/bin)" /usr/local/node-bin
ENV PATH="/usr/local/node-bin:$PATH"

# SSH 配置
RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && echo 'PATH="/usr/local/node-bin:/usr/local/bin:/usr/bin:/bin"' > /etc/environment
# sshd 会话环境来自 PAM (pam_env 读 /etc/environment), 不继承镜像 ENV;
# 上面写入 node 路径, 保证 ssh host 'cmd' 等非登录 shell (不读 .profile) 也能用 node

# sing-box 配置 (模板; 镜像不内置任何代理服务器信息, SSH 代理由运行时环境变量渲染)
COPY configs/sing-box/config.json /etc/sing-box/config.json

# 启动脚本 (sshd) 与手动 SSH 代理配置脚本
COPY scripts/start.sh /usr/local/bin/start.sh
COPY scripts/render-ssh-proxy.sh /usr/local/bin/render-ssh-proxy.sh
RUN chmod +x /usr/local/bin/start.sh /usr/local/bin/render-ssh-proxy.sh

EXPOSE 22

CMD ["/usr/local/bin/start.sh"]
