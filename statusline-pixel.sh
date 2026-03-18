#!/bin/bash
# 像素游戏风状态栏 - Pixel Gaming Theme
# 显示：等级、经验条、今日统计

# 读取 JSON 输入
input=$(cat)

# 获取当前工作目录
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
[ -z "$current_dir" ] && current_dir=$(pwd)

# 提取目录名
dir_name=$(basename "$current_dir")

# ===== 1. 时间 =====
hour=$(date +%H)
minute=$(date +%M)
time_str=$(date +%H:%M)

# ===== 2. 等级系统 =====
# 根据时间段计算等级（早起的鸟儿等级高）
# 0-5点: Lv.10 (夜猫子奖励)
# 6-8点: Lv.8 (早起鸟)
# 9-12点: Lv.5
# 13-18点: Lv.4
# 19-23点: Lv.3
case $hour in
    0|1|2|3|4|5) level=10; role="🦇 夜行者" ;;
    6|7|8) level=8; role="🌅 早鸟" ;;
    9|10|11) level=6; role="⚔️ 战士" ;;
    12|13|14|15) level=5; role="🔨 工匠" ;;
    16|17|18) level=4; role="📜 学者" ;;
    19|20) level=3; role="🌙 守夜人" ;;
    21|22|23) level=2; role="💤 修行中" ;;
esac

# 根据星期调整等级（周末奖励）
day_of_week=$(date +%u)
if [ $day_of_week -ge 6 ]; then
    level=$((level + 1))
    role="🎉 周末${role}"
fi

# ===== 3. 经验值计算 =====
# 基于时间（每分钟+1 XP）
current_minutes=$((hour * 60 + minute))
xp=$((current_minutes % 1000))

# 每级需要的经验
xp_needed=$((level * 100))
xp_percent=$((xp * 100 / xp_needed))
[ $xp_percent -gt 100 ] && xp_percent=100

# ===== 4. 今日统计 =====
# 统计今日执行的命令数（从历史估算）
today_commands=$(history | wc -l | tr -d ' ')
# 限制在合理范围
[ -z "$today_commands" ] && today_commands=0
today_commands=$((today_commands % 100))

# 计算完成任务数（估算）
tasks_done=$((today_commands / 10))

# ===== 5. Git 状态（游戏化表达）=====
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
# 第一行：等级和时间
output="${FG_GOLD}[Lv.${level}]${RESET} ${role}  ${DIM}${time_str}${RESET}"
output+="\n"

# 第二行：经验条
output+="${xp_percent}%%  ${FG_GREEN}[${bar}]${RESET} ${xp}/${xp_needed}XP"
output+="\n"

# 第三行：今日统计
output+="${FG_CYAN}🎯 今日:${RESET} ${tasks_done}任务  ${FG_ORANGE}⚔️ 执行:${RESET} ${today_commands}次"

# Git 状态（如果有）
if [ -n "$git_status" ]; then
    output+="  ${FG_MAGENTA}${git_status}${RESET}"
fi

# 目录名（简洁显示）
if [ "$dir_name" != "$(basename $HOME)" ] && [ "$dir_name" != "." ]; then
    output+="  ${DIM}|${RESET} ${FG_PURPLE}${dir_name}${RESET}"
fi

printf "$output"
