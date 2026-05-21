#!/bin/bash
set -e

echo "🚀 Starting build..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

npm run build

echo "📦 Build finished."

TARGET_WEB="../rm_synapse/ui/web"

echo "🧹 Removing old web directory..."
rm -rf "$TARGET_WEB"
mkdir -p "$TARGET_WEB"

echo "📂 Copying dist contents to target..."
cp -R dist/. "$TARGET_WEB/"

echo "✅ Deployment completed successfully!"
echo "📁 Target files:"
find "$TARGET_WEB" -maxdepth 2 -type f
