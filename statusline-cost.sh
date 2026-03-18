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
STATS_FILE="$HOME/.claude/cost-stats.txt"

# 初始化
if [ ! -f "$STATS_FILE" ]; then
    echo "$(date +%s)|0" > "$STATS_FILE"
fi

# 读取数据
session_start=$(cut -d'|' -f1 "$STATS_FILE")
commands_count=$(cut -d'|' -f2 "$STATS_FILE")

# 更新命令计数
commands_count=$((commands_count + 1))

# 保存数据
echo "${session_start}|${commands_count}" > "$STATS_FILE"

# ===== Token 估算 =====
total_tokens=$((commands_count * 2000))

if [ $total_tokens -gt 1000000 ]; then
    tokens_m=$((total_tokens / 1000000))
    tokens_str="${tokens_m}M"
elif [ $total_tokens -gt 1000 ]; then
    tokens_k=$((total_tokens / 1000))
    tokens_str="${tokens_k}k"
else
    tokens_str="${total_tokens}"
fi

# ===== 时长 =====
current_time=$(date +%s)
session_duration=$((current_time - session_start))
hours=$((session_duration / 3600))
minutes=$(((session_duration % 3600) / 60))

if [ $hours -gt 0 ]; then
    duration_str="${hours}h ${minutes}m"
else
    duration_str="${minutes}m"
fi

# ===== 成本 =====
cost_dollars=$((total_tokens * 3 / 1000000))
cost_cents=$((total_tokens * 3 / 10000 % 100))
cost_str="\$${cost_dollars}.${cost_cents}"

# ===== 配色 =====
FG_GREEN="\\033[38;2;50;205;50m"
FG_CYAN="\\033[38;2;0;255;255m"
FG_ORANGE="\\033[38;2;255;140;0m"
FG_RED="\\033[38;2;255;69;0m"
FG_GRAY="\\033[38;2;128;128;128m"
DIM="\\033[2m"
RESET="\\033[0m"

if [ $cost_dollars -lt 5 ]; then
    cost_color=$FG_GREEN
elif [ $cost_dollars -lt 20 ]; then
    cost_color=$FG_ORANGE
else
    cost_color=$FG_RED
fi

# ===== 输出 =====
output="${cost_color}💰 ${cost_str}${RESET}  ${FG_CYAN}📊 ${tokens_str} tokens${RESET}  ${FG_GREEN}⏱️  ${duration_str}${RESET}"
output+="\n"
output+="📝 命令: ${commands_count}次  ${DIM}$(date +%H:%M:%S)${RESET}"

if [ "$dir_name" != "$(basename $HOME)" ] && [ "$dir_name" != "." ]; then
    output+="  ${DIM}|${RESET} ${FG_GRAY}${dir_name}${RESET}"
fi

printf "$output"
