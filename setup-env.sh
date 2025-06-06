#!/bin/bash

# 安全设置脚本 - 创建本地开发环境的 .env 文件

echo "🔐 设置本地开发环境"
echo "==================="

# 检查是否已存在 .env 文件
if [ -f ".env" ]; then
    echo "⚠️  .env 文件已存在"
    read -p "是否要覆盖现有的 .env 文件? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        echo "❌ 操作已取消"
        exit 0
    fi
fi

# 检查可用的SSH公钥
echo ""
echo "🔍 检查可用的SSH公钥..."

ssh_keys=()
if [ -f ~/.ssh/id_rsa.pub ]; then
    ssh_keys+=("~/.ssh/id_rsa.pub")
fi
if [ -f ~/.ssh/id_ed25519.pub ]; then
    ssh_keys+=("~/.ssh/id_ed25519.pub")
fi
if [ -f ~/.ssh/id_ecdsa.pub ]; then
    ssh_keys+=("~/.ssh/id_ecdsa.pub")
fi

if [ ${#ssh_keys[@]} -eq 0 ]; then
    echo "❌ 未找到SSH公钥文件"
    echo "请先生成SSH密钥:"
    echo "ssh-keygen -t ed25519 -C \"your-email@example.com\""
    exit 1
fi

echo "找到以下SSH公钥:"
for i in "${!ssh_keys[@]}"; do
    echo "$((i+1)). ${ssh_keys[$i]}"
done

# 让用户选择密钥
if [ ${#ssh_keys[@]} -eq 1 ]; then
    selected_key="${ssh_keys[0]}"
    echo "✅ 自动选择: $selected_key"
else
    echo ""
    read -p "请选择要使用的SSH公钥 (1-${#ssh_keys[@]}): " choice
    if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "${#ssh_keys[@]}" ]; then
        selected_key="${ssh_keys[$((choice-1))]}"
    else
        echo "❌ 无效选择"
        exit 1
    fi
fi

# 展开波浪号路径
expanded_key="${selected_key/#\~/$HOME}"

# 读取SSH公钥内容
ssh_public_key=$(cat "$expanded_key")

# 创建 .env 文件
cat > .env << EOF
# 本地开发环境配置
# 警告：此文件包含敏感信息，不要提交到Git！

# SSH公钥 (来自: $selected_key)
SSH_PUBLIC_KEY=$ssh_public_key
EOF

echo ""
echo "✅ .env 文件创建成功!"
echo "📁 位置: $(pwd)/.env"
echo ""
echo "⚠️  重要提醒:"
echo "   - .env 文件已在 .gitignore 中，不会被Git跟踪"
echo "   - 请不要手动将 .env 文件添加到Git"
echo "   - 现在可以运行: docker-compose up -d"
echo ""
