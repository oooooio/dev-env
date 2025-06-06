# Docker开发环境

这是一个基于Ubuntu的Docker开发环境，包含SSH服务器和你的SSH公钥。

## 设置说明

### 1. 添加SSH公钥到GitHub Secrets

1. 进入你的GitHub仓库
2. 点击 Settings → Secrets and variables → Actions
3. 点击 "New repository secret"
4. 名称: `SSH_PUBLIC_KEY`
5. 值: 你的SSH公钥内容（通常在 `~/.ssh/id_rsa.pub` 或 `~/.ssh/id_ed25519.pub`）

⚠️ **重要安全提醒**:
- ✅ `.env.example` 可以安全地提交到Git（它只是模板）
- ❌ **绝不要**将真实的 `.env` 文件提交到Git（包含真实密钥）
- ✅ `.env` 已在 `.gitignore` 中，确保不会被意外提交

### 2. 获取SSH公钥

在你的Mac上运行以下命令来获取SSH公钥：

```bash
# 查看现有的SSH密钥
ls -la ~/.ssh/

# 显示公钥内容（如果使用RSA密钥）
cat ~/.ssh/id_rsa.pub

# 或者如果使用Ed25519密钥
cat ~/.ssh/id_ed25519.pub

# 如果没有SSH密钥，创建一个新的
ssh-keygen -t ed25519 -C "your-email@example.com"
```

### 3. 构建和运行

当你推送代码到main分支时，GitHub Actions会自动构建Docker镜像。

你也可以手动触发构建：
1. 进入GitHub仓库的Actions页面
2. 选择 "Build Development Environment" workflow
3. 点击 "Run workflow"

### 4. 使用开发环境

构建完成后，你可以这样使用：

```bash
# 拉取镜像
docker pull ghcr.io/your-username/dev-base/dev-env:latest

# 运行容器
docker run -d -p 2222:22 --name dev-env ghcr.io/your-username/dev-base/dev-env:latest

# 通过SSH连接（必须使用私钥，密码登录已禁用）
ssh -p 2222 root@localhost

# 如果使用特定的私钥文件
ssh -i ~/.ssh/id_ed25519 -p 2222 root@localhost

# 或者直接进入容器（不通过SSH）
docker exec -it dev-env bash
```

**重要**: 现在只能通过SSH密钥登录，密码认证已完全禁用。

### 5. 高级使用

#### 挂载工作目录
```bash
docker run -d -p 2222:22 -v $(pwd):/workspace --name dev-env ghcr.io/your-username/dev-base/dev-env:latest
```

#### 自定义端口
```bash
docker run -d -p 3333:22 --name dev-env ghcr.io/your-username/dev-base/dev-env:latest
ssh -p 3333 root@localhost
```

## 包含的软件

- Ubuntu Latest
- OpenSSH Server
- Git
- Vim
- Curl
- Build Essential (gcc, make等)
- Sudo

## 安全说明

- **仅支持SSH密钥认证** - 密码登录已完全禁用
- **必须提供SSH公钥** - 构建时必须提供SSH_PUBLIC_KEY参数
- **Root用户仅允许密钥登录** - PermitRootLogin设置为prohibit-password
- **禁用所有密码认证方式** - PasswordAuthentication和ChallengeResponseAuthentication均已禁用
- **建议仅在开发环境中使用**

## 自定义

你可以修改 `Dockerfile` 来添加更多开发工具或配置。每次推送到main分支都会自动重新构建镜像。

## 本地开发

对于本地开发，你可以使用Docker Compose：

```bash
# 方法1：使用安全设置脚本（推荐）
./setup-env.sh

# 方法2：手动创建环境变量文件
cp .env.example .env
# 然后编辑 .env 文件，填入你的SSH公钥

# 启动开发环境
docker-compose up -d

# 连接到开发环境
ssh -p 2222 root@localhost

# 停止开发环境
docker-compose down
```

⚠️ **重要**: 无论使用哪种方法，都要确保：
- `.env` 文件包含你真实的SSH公钥
- 绝不要将 `.env` 文件提交到Git
- 使用 `setup-env.sh` 脚本可以自动处理这些安全问题
