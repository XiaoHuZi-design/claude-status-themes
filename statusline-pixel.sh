#!/bin/bash
# 像素游戏风状态栏 - Pixel Gaming Theme (真实等级累积版)
# 显示：等级、经验条、今日统计

# 读取 JSON 输入
input=$(cat)

# 获取当前工作目录
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
[ -z "$current_dir" ] && current_dir=$(pwd)

# 提取目录名
dir_name=$(basename "$current_dir")

# ===== 数据文件 =====
STATS_FILE="$HOME/.claude/pixel-stats.json"

# 初始化数据文件
if [ ! -f "$STATS_FILE" ]; then
    cat > "$STATS_FILE" << 'EOF'
{
  "total_xp": 0,
  "level": 1,
  "commands_today": 0,
  "last_date": "",
  "achievements": []
}
EOF
fi

# 读取当前数据
total_xp=$(jq -r '.total_xp' "$STATS_FILE")
[ -z "$total_xp" ] && total_xp=0

commands_today=$(jq -r '.commands_today' "$STATS_FILE")
[ -z "$commands_today" ] && commands_today=0

last_date=$(jq -r '.last_date' "$STATS_FILE")
[ -z "$last_date" ] && last_date=""

today=$(date +%Y-%m-%d)

# 检查是否是新的一天，重置今日计数
if [ "$last_date" != "$today" ]; then
    commands_today=0
fi

# ===== 增加经验值 =====
# 每次执行 +1 XP
# 周末 +2 XP
# 深夜(0-5点)或清晨(6-8点) +1 XP 额外奖励
xp_gain=1
day_of_week=$(date +%u)
if [ $day_of_week -ge 6 ]; then
    xp_gain=$((xp_gain + 1))  # 周末奖励
fi

hour=$(date +%H)
if [ $hour -lt 6 ] || ([ $hour -ge 6 ] && [ $hour -lt 9 ]); then
    xp_gain=$((xp_gain + 1))  # 深夜/清晨奖励
fi

# 更新数据
total_xp=$((total_xp + xp_gain))
commands_today=$((commands_today + 1))

# ===== 计算等级（渐进式） =====
# 等级1: 0-99 XP
# 等级2: 100-399 XP (需要300)
# 等级3: 400-899 XP (需要500)
# 等级4: 900-1599 XP (需要700)
# 简化公式: 每 100 XP 升 1 级
level=$((total_xp / 100 + 1))

# 计算当前等级的 XP 范围
prev_level=$(((level - 1) * (level - 1) * 100))
next_level=$((level * level * 100))
current_level_xp=$((total_xp - prev_level))
level_xp_needed=$((next_level - prev_level))

# 计算百分比
if [ $level_xp_needed -gt 0 ]; then
    xp_percent=$((current_level_xp * 100 / level_xp_needed))
else
    xp_percent=100
fi
[ $xp_percent -gt 100 ] && xp_percent=100

# 保存数据
jq --arg xp "$total_xp" \
   --arg lvl "$level" \
   --arg cmd "$commands_today" \
   --arg date "$today" \
   '.total_xp = ($xp | tonumber) | .level = ($lvl | tonumber) | .commands_today = ($cmd | tonumber) | .last_date = $date' \
   "$STATS_FILE" > "${STATS_FILE}.tmp" && mv "${STATS_FILE}.tmp" "$STATS_FILE"

# ===== 1. 时间 =====
minute=$(date +%M)
time_str=$(date +%H:%M)

# ===== 2. 角色称号（按时段）=====
case $hour in
    0|1|2|3|4|5) role="🦇 夜行者" ;;
    6|7|8) role="🌅 早鸟" ;;
    9|10|11) role="⚔️ 战士" ;;
    12|13|14|15) role="🔨 工匠" ;;
    16|17|18) role="📜 学者" ;;
    19|20) role="🌙 守夜人" ;;
    21|22|23) role="💤 修行中" ;;
esac

# 周末标记
if [ $day_of_week -ge 6 ]; then
    role="🎉 周末${role}"
fi

# ===== 3. 计算完成任务数 =====
tasks_done=$((commands_today / 10))

# ===== 4. Git 状态（游戏化表达）=====
git_status=""
cd "$current_dir" 2>/dev/null
if git rev-parse --git-dir >/dev/null 2>&1; then
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git_status="⚠️ 未存档"
    else
        git_status="💾 已存档"
    fi
fi

# ===== 配色方案（像素游戏风）=====
FG_GOLD="\\033[38;2;255;215;0m"      # 金色
FG_GREEN="\\033[38;2;50;205;50m"     # 亮绿
FG_CYAN="\\033[38;2;0;255;255m"      # 青色
FG_MAGENTA="\\033[38;2;255;0;255m"   # 洋红
FG_ORANGE="\\033[38;2;255;140;0m"    # 橙色
FG_PURPLE="\\033[38;2;147;112;219m"  # 紫色
FG_GRAY="\\033[38;2;128;128;128m"    # 灰色
DIM="\\033[2m"
RESET="\\033[0m"

# ===== 构建经验条（20格）=====
filled=$((xp_percent / 5))
empty=$((20 - filled))
bar=""
for ((i=0; i<filled; i++)); do bar+="█"; done
for ((i=0; i<empty; i++)); do bar+="░"; done

# ===== 构建输出 =====
# 第一行：等级、称号、时间
output="${FG_GOLD}[Lv.${level}]${RESET} ${role}  ${DIM}${time_str}${RESET}"
output+="\n"

# 第二行：经验条
output+="${xp_percent}%%  ${FG_GREEN}[${bar}]${RESET} ${current_level_xp}/${level_xp_needed}XP"
output+="\n"

# 第三行：今日统计
output+="${FG_CYAN}🎯 今日:${RESET} ${tasks_done}任务  ${FG_ORANGE}⚔️ 执行:${RESET} ${commands_today}次  ${FG_PURPLE}💎 总XP:${RESET} ${total_xp}"

# Git 状态（如果有）
if [ -n "$git_status" ]; then
    output+="  ${FG_MAGENTA}${git_status}${RESET}"
fi

# 目录名（简洁显示）
if [ "$dir_name" != "$(basename $HOME)" ] && [ "$dir_name" != "." ]; then
    output+="  ${DIM}|${RESET} ${FG_PURPLE}${dir_name}${RESET}"
fi

printf "$output"
