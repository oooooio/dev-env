FROM dhi.io/debian-base:trixie-debian13-dev

ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_NO_DEV=1 \
    UV_NO_EDITABLE=1 \
    UV_LINK_MODE=copy \
    UV_VENV_DIR=/venv \
    GH_PROXY=https://gh-proxy.com \
    FNM_DIR=/home/20zhaiyilin/.local/share/fnm \
    HF_ENDPOINT=https://hf-mirror.com

ENV PATH="$FNM_DIR:$PATH"

# 安装基础依赖
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git vim tmux openssh-server python3 unzip ripgrep sudo \
    && rm -rf /var/lib/apt/lists/*

# 创建普通用户并授权 sudo
RUN useradd -m -s /bin/bash 20zhaiyilin \
    && echo "20zhaiyilin ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/20zhaiyilin \
    && mkdir -p /home/20zhaiyilin/.ssh \
    && chmod 700 /home/20zhaiyilin/.ssh \
    && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCXQNggLyEZhjxf0CBOdXOK2DzgEa5AmoAMsEaAvR9G' > /home/20zhaiyilin/.ssh/authorized_keys \
    && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDPGn4blND4QhvGbXdD7EYo/PMi7hkVb1WsdFDxWQCf' >> /home/20zhaiyilin/.ssh/authorized_keys \
    && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBSfiYu7iqqMvoVmMqcqApM44osw44T6nKzF/LPg5uoh' >> /home/20zhaiyilin/.ssh/authorized_keys \
    && chmod 600 /home/20zhaiyilin/.ssh/authorized_keys \
    && chown -R 20zhaiyilin:20zhaiyilin /home/20zhaiyilin/.ssh

# 安装 uv (系统级)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mkdir -p /usr/local/bin \
    && mv /root/.local/bin/uv /usr/local/bin/uv \
    && mv /root/.local/bin/uvx /usr/local/bin/uvx

# 安装 rtk (系统级)
RUN curl -LsSf "https://github.com/rtk-ai/rtk/releases/download/v0.42.0/rtk-x86_64-unknown-linux-musl.tar.gz" \
    | tar xz -C /usr/local/bin

# 用户级工具 (fnm, node, npm 全局包)
USER 20zhaiyilin

RUN git config --global url."${GH_PROXY}/https://github.com/".insteadOf https://github.com/ \
    && curl -o- https://fnm.vercel.app/install | bash \
    && eval "$(fnm env)" \
    && fnm install 24 \
    && fnm use 24 \
    && npm i -g opencode-ai @anthropic-ai/claude-code \
    && npm config set registry https://registry.npmmirror.com

USER root

# 全部安装完成后切换为清华源
RUN cat > /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/debian
Suites: trixie trixie-updates trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

# SSH 配置
RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# uv 配置
RUN mkdir -p /home/20zhaiyilin/.config/uv
COPY --chown=20zhaiyilin:20zhaiyilin configs/uv.toml /home/20zhaiyilin/.config/uv/uv.toml

# 设置镜像环境变量
ENV UV_PYTHON_INSTALL_MIRROR=${GH_PROXY}/https://github.com/astral-sh/python-build-standalone/releases/download \
    FNM_NODE_DIST_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
