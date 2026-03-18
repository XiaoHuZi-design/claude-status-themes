#!/bin/bash
# 成本追踪器状态栏 - Cost Tracker Theme
# 显示：花费、Token使用、会话时长

# 读取 JSON 输入
input=$(cat)

# 获取当前工作目录
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
[ -z "$current_dir" ] && current_dir=$(pwd)

# 提取目录名
dir_name=$(basename "$current_dir")

# ===== 数据文件 =====
STATS_FILE="$HOME/.claude/cost-stats.json"

# 初始化数据文件
if [ ! -f "$STATS_FILE" ]; then
    cat > "$STATS_FILE" << 'EOF'
{
  "session_start": null,
  "commands_count": 0,
  "total_tokens": 0,
  "last_update": ""
}
EOF
fi

# 读取当前数据
session_start=$(jq -r '.session_start' "$STATS_FILE")
commands_count=$(jq -r '.commands_count' "$STATS_FILE")
total_tokens=$(jq -r '.total_tokens' "$STATS_FILE")

# 初始化会话开始时间
if [ "$session_start" = "null" ] || [ -z "$session_start" ]; then
    session_start=$(date +%s)
    jq --arg start "$session_start" '.session_start = ($start | tonumber)' "$STATS_FILE" > "${STATS_FILE}.tmp" && mv "${STATS_FILE}.tmp" "$STATS_FILE"
fi

# ===== 1. 计算会话时长 =====
current_time=$(date +%s)
session_duration=$((current_time - session_start))
hours=$((session_duration / 3600))
minutes=$(((session_duration % 3600) / 60))
seconds=$((session_duration % 60))

# 格式化时长
if [ $hours -gt 0 ]; then
    duration_str="${hours}h ${minutes}m"
elif [ $minutes -gt 0 ]; then
    duration_str="${minutes}m ${seconds}s"
else
    duration_str="${seconds}s"
fi

# ===== 2. 估算 Token 使用 =====
# 基于命令历史估算
if [ "$total_tokens" -eq 0 ]; then
    cmd_history=$(history | wc -l | tr -d ' ')
    [ -z "$cmd_history" ] && cmd_history=0
    total_tokens=$((cmd_history * 2000))
fi

# 格式化 token 数
if [ $total_tokens -gt 1000000 ]; then
    tokens_m=$((total_tokens / 1000000))
    tokens_str="${tokens_m}M"
elif [ $total_tokens -gt 1000 ]; then
    tokens_k=$((total_tokens / 1000))
    tokens_str="${tokens_k}k"
else
    tokens_str="${total_tokens}"
fi

# ===== 3. 计算成本 =====
# 估算：每 1000 tokens 约 $0.003
cost_dollars=$((total_tokens * 3 / 1000000))
cost_cents=$((total_tokens * 3 / 10000 % 100))
cost_str="\$${cost_dollars}.${cost_cents}"

# ===== 配色方案 =====
FG_GOLD="\\033[38;2;255;215;0m"      # 金色
FG_GREEN="\\033[38;2;50;205;50m"     # 亮绿
FG_CYAN="\\033[38;2;0;255;255m"      # 青色
FG_ORANGE="\\033[38;2;255;140;0m"    # 橙色
FG_RED="\\033[38;2;255;69;0m"        # 红色
FG_GRAY="\\033[38;2;128;128;128m"    # 灰色
DIM="\\033[2m"
RESET="\\033[0m"

# 成本颜色
if [ $cost_dollars -lt 5 ]; then
    cost_color=$FG_GREEN
elif [ $cost_dollars -lt 20 ]; then
    cost_color=$FG_ORANGE
else
    cost_color=$FG_RED
fi

# ===== 构建输出 =====
# 第一行：成本、Token、时长
output="${cost_color}💰 ${cost_str}${RESET}  ${FG_CYAN}📊 ${tokens_str} tokens${RESET}  ${FG_GREEN}⏱️  ${duration_str}${RESET}"
output+="\n"

# 第二行：命令统计
output+="📝 命令: ${commands_count}次  ${DIM}$(date +%H:%M:%S)${RESET}"

# 目录名
if [ "$dir_name" != "$(basename $HOME)" ] && [ "$dir_name" != "." ]; then
    output+="  ${DIM}|${RESET} ${FG_GRAY}${dir_name}${RESET}"
fi

printf "$output"
