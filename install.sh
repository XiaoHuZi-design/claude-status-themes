#!/bin/bash
# Claude Code 状态栏主题安装脚本

set -e

CLAUDE_DIR="$HOME/.claude"
THEME="geek"  # 默认主题

echo "🚀 安装 Claude Code 状态栏主题..."
echo

# 检查 Claude 目录
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "❌ 未找到 .claude 目录"
    exit 1
fi

# 复制脚本
echo "📄 复制状态栏脚本..."
cp statusline-*.sh "$CLAUDE_DIR/"
cp switch-theme.sh "$CLAUDE_DIR/"
chmod +x "$CLAUDE_DIR"/statusline-*.sh
chmod +x "$CLAUDE_DIR"/switch-theme.sh

# 复制 skill
echo "📦 安装斜杠命令..."
cp -r sb "$CLAUDE_DIR/skills/"

# 配置 settings.json
echo "⚙️  配置 settings.json..."
SETTINGS="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS" ]; then
    # 使用 jq 或 sed 添加配置
    if command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        jq --arg cmd "bash ~/.claude/statusline-geek.sh" \
           '.statusLine = {"type": "command", "command": $cmd}' \
           "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

        # 添加 spinnerVerbs
        jq --argjson verbs '$(cat spinner-verbs.json)' \
           '.spinnerVerbs = $verbs' \
           "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    else
        echo "⚠️  未安装 jq，请手动配置 settings.json"
    fi
else
    echo "⚠️  未找到 settings.json，请手动配置"
fi

echo
echo "✅ 安装完成！"
echo
echo "📌 使用方法："
echo "   重启 Claude Code 后使用:"
echo "   /sb geek      - 极客仪表盘"
echo "   /sb xianxia   - 仙侠古风"
echo "   /sb pixel     - 像素游戏"
echo
echo "   或直接执行:"
echo "   ~/.claude/switch-theme.sh geek"
