FROM ubuntu:24.04

ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_NO_CACHE=1 \
    UV_NO_DEV=1 \
    UV_NO_EDITABLE=1 \
    UV_VENV_DIR=/venv \
    GH_PROXY=https://gh-proxy.com \
    FNM_DIR=/root/.local/share/fnm

ENV PATH="$FNM_DIR:$PATH"

# 安装基础依赖和工具
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git vim openssh-server python3 unzip \
    && rm -rf /var/lib/apt/lists/* \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/uv \
    && mv /root/.local/bin/uvx /usr/local/bin/uvx \
    && git config --global url."${GH_PROXY}/https://github.com/".insteadOf https://github.com/ \
    && curl -o- https://fnm.vercel.app/install | bash \
    && export FNM_DIR="/root/.local/share/fnm" \
    && export PATH="$FNM_DIR:$PATH" \
    && fnm install 24 \
    && fnm use 24 \
    && npm i -g opencode-ai \
    && npm config set registry https://registry.npmmirror.com

# 全部安装完成后切换为清华源
RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|https://mirrors.tuna.tsinghua.edu.cn/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources \
    && sed -i 's|http://security.ubuntu.com/ubuntu/|https://mirrors.tuna.tsinghua.edu.cn/ubuntu/|g' /etc/apt/sources.list.d/ubuntu.sources

# SSH 配置
RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# uv 配置
RUN mkdir -p /root/.config/uv
COPY configs/uv.toml /root/.config/uv/uv.toml
RUN chmod 644 /root/.config/uv/uv.toml

# 设置镜像环境变量
ENV UV_PYTHON_INSTALL_MIRROR=${GH_PROXY}/https://github.com/astral-sh/python-build-standalone/releases/download \
    FNM_NODE_DIST_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
