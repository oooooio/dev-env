FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive

# 更换为清华源
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list

# 安装必要的软件包
RUN apt-get update && apt-get install -y \
    openssh-server \
    curl \
    git \
    vim \
    sudo \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 创建SSH目录
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# 配置SSH服务
RUN mkdir /var/run/sshd

# 配置SSH安全设置：禁用密码登录，仅允许密钥认证
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# 复制SSH公钥（必须提供，否则无法SSH连接）
ARG SSH_PUBLIC_KEY
RUN if [ -z "$SSH_PUBLIC_KEY" ]; then \
        echo "错误: SSH_PUBLIC_KEY 构建参数是必需的！" && \
        echo "请在构建时提供你的SSH公钥：" && \
        echo "docker build --build-arg SSH_PUBLIC_KEY=\"$(cat ~/.ssh/id_ed25519.pub)\" ." && \
        exit 1; \
    fi && \
    echo "🔑 设置SSH公钥 (前30字符): $(echo "$SSH_PUBLIC_KEY" | cut -c1-30)..." && \
    echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    chown root:root /root/.ssh/authorized_keys && \
    echo "✅ SSH公钥设置完成"

# 暴露SSH端口
EXPOSE 22

# 启动SSH服务
CMD ["/usr/sbin/sshd", "-D"]