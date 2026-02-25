#!/bin/bash

# 出现错误立即退出
set -e

echo "🚀 Starting build..."

# 进入脚本所在目录（防止从别的路径执行出问题）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. 构建
npm run build

echo "📦 Build finished."

# 2. 删除旧目录
TARGET_WEB="../rm_synapse/ui/web"

echo "🧹 Removing old directories..."
rm -rf "$TARGET_WEB"

# 3. 复制 dist
echo "📂 Copying dist to target..."

cp -r dist "$TARGET_WEB"

echo "✅ Deployment completed successfully!"