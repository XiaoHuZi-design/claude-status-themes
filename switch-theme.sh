#!/bin/bash
# 状态栏主题切换脚本
# 用法: ~/.claude/switch-theme.sh [xianxia|geek|pixel]

THEME="${1:-geek}"
SETTINGS_FILE="$HOME/.claude/settings.json"

case "$THEME" in
    xianxia|仙侠|x)
        COMMAND="bash ~/.claude/statusline-xianxia.sh"
        NAME="仙侠古风"
        ;;
    geek|极客|g)
        COMMAND="bash ~/.claude/statusline-geek.sh"
        NAME="极客仪表盘"
        ;;
    pixel|像素|p|游戏)
        COMMAND="bash ~/.claude/statusline-pixel.sh"
        NAME="像素游戏"
        ;;
    *)
        echo "用法: $0 [xianxia|geek|pixel]"
        echo "  xianxia, 仙侠, x  - 仙侠古风主题"
        echo "  geek, 极客, g     - 极客仪表盘主题"
        echo "  pixel, 像素, p    - 像素游戏主题"
        exit 1
        ;;
esac

# 使用 jq 修改 settings.json（如果已安装）
if command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq --arg cmd "$COMMAND" '.statusLine.command = $cmd' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    echo "✅ 已切换到: $NAME"
else
    # 如果没有 jq，使用 sed
    sed -i '' 's|"command": "bash ~/\.claude/statusline-.*\.sh"|"command": "'"$COMMAND"'"|' "$SETTINGS_FILE"
    echo "✅ 已切换到: $NAME"
fi
