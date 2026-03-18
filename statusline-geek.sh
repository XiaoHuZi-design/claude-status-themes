#!/bin/bash
# 极客仪表盘状态栏 - Geek Dashboard Status Bar
# 显示：时间 | Git分支+状态 | 内存 | Node版本

# 读取 JSON 输入
input=$(cat)

# 获取当前工作目录
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
[ -z "$current_dir" ] && current_dir=$(pwd)

# 提取目录名
dir_name=$(basename "$current_dir")

# ===== 1. 时间 =====
time_str=$(date +%H:%M)

# ===== 2. Git 分支状态 =====
git_status=""
git_branch=""

# 检查是否在 git 仓库中
cd "$current_dir" 2>/dev/null
if git rev-parse --git-dir >/dev/null 2>&1; then
    # 获取当前分支名
    git_branch=$(git branch --show-current 2>/dev/null || echo "unknown")

    # 检查是否有未提交的修改
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git_status="*"  # 有修改
    else
        git_status=""   # 干净
    fi
fi

git_display="${git_branch}${git_status}"
[ -z "$git_branch" ] && git_display="no-git"

# ===== 3. 内存使用率 (macOS) =====
mem_percent=""
if command -v vm_stat >/dev/null 2>&1; then
    # macOS: 使用 vm_stat 获取内存信息
    vm_stats=$(vm_stat)

    # 获取各类型页面数（移除末尾的点和空格）
    free_pages=$(echo "$vm_stats" | awk '/Pages free/ {print $3}' | tr -d '.')
    active_pages=$(echo "$vm_stats" | awk '/Pages active/ {print $3}' | tr -d '.')
    inactive_pages=$(echo "$vm_stats" | awk '/Pages inactive/ {print $3}' | tr -d '.')
    wired_pages=$(echo "$vm_stats" | awk '/Pages wired down/ {print $4}' | tr -d '.')
    speculative_pages=$(echo "$vm_stats" | awk '/Pages speculative/ {print $3}' | tr -d '.')

    # 确保数值不为空
    [ -z "$free_pages" ] && free_pages=0
    [ -z "$active_pages" ] && active_pages=0
    [ -z "$inactive_pages" ] && inactive_pages=0
    [ -z "$wired_pages" ] && wired_pages=0
    [ -z "$speculative_pages" ] && speculative_pages=0

    # 计算总页面和已用页面
    # 已用 = active + wired（inactive 和 speculative 算可用）
    total_pages=$((free_pages + active_pages + inactive_pages + wired_pages + speculative_pages))
    used_pages=$((active_pages + wired_pages))

    if [ $total_pages -gt 0 ]; then
        mem_percent=$(( (used_pages * 100) / total_pages ))
    fi
fi

# ===== 4. Node 版本（如果存在）=====
node_version=""
if [ -f "$current_dir/package.json" ] || [ -d "$current_dir/node_modules" ]; then
    if command -v node >/dev/null 2>&1; then
        node_version=$(node -v 2>/dev/null | sed 's/v//' || echo "")
    fi
fi

# 如果没有 Node，尝试 Python
if [ -z "$node_version" ] && { [ -f "$current_dir/requirements.txt" ] || [ -f "$current_dir/pyproject.toml" ] || [ -f "$current_dir/setup.py" ]; }; then
    if command -v python3 >/dev/null 2>&1; then
        py_version=$(python3 --version 2>/dev/null | awk '{print $2}')
        node_version="py${py_version}"
    fi
fi

# ===== 5. CPU 使用率（可选，macOS）=====
cpu_percent=""
if command -v ps >/dev/null 2>&1; then
    # 获取当前 CPU 使用率（采样）
    cpu_usage=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.0f", s}')
    # 限制在合理范围
    if [ "$cpu_usage" -gt 0 ] && [ "$cpu_usage" -le 1000 ]; then
        cpu_percent=$((cpu_usage / $(sysctl -n hw.ncpu 2>/dev/null || echo 1)))
        [ $cpu_percent -gt 100 ] && cpu_percent=100
    fi
fi

# ===== 配色方案（赛博霓虹）=====
FG_CYAN="\\033[38;2;0;255;255m"       # 青色
FG_MAGENTA="\\033[38;2;255;0;255m"    # 洋红
FG_GREEN="\\033[38;2;0;255;128m"      # 绿色
FG_YELLOW="\\033[38;2;255;255;0m"     # 黄色
FG_ORANGE="\\033[38;2;255;165;0m"     # 橙色
FG_BLUE="\\033[38;2;100;149;237m"     # 矢车菊蓝
FG_GRAY="\\033[38;2;128;128;128m"     # 灰色
DIM="\\033[2m"
RESET="\\033[0m"

# ===== 构建输出 =====
# 第一行：主要信息
output="${FG_CYAN}⚡${RESET} ${DIM}${time_str}${RESET}"
output+="  ${FG_GRAY}|${RESET}  "

# Git 分支（有修改显示橙色，干净显示绿色）
if [ "$git_status" = "*" ]; then
    output+="${FG_ORANGE}🔥 ${git_display}${RESET}"
else
    output+="${FG_GREEN}🌿 ${git_display}${RESET}"
fi

output+="  ${FG_GRAY}|${RESET}  "

# 内存使用（根据占用率变色）
if [ -n "$mem_percent" ]; then
    if [ $mem_percent -lt 50 ]; then
        output+="${FG_GREEN}💾 ${mem_percent}%%${RESET}"
    elif [ $mem_percent -lt 80 ]; then
        output+="${FG_YELLOW}💾 ${mem_percent}%%${RESET}"
    else
        output+="${FG_MAGENTA}💾 ${mem_percent}%%${RESET}"
    fi
fi

# Node/Python 版本
if [ -n "$node_version" ]; then
    output+="  ${FG_GRAY}|${RESET}  ${FG_BLUE}🚀 ${node_version}${RESET}"
fi

# 可选：第二行 CPU 进度条（如果 CPU 使用率较高才显示）
if [ -n "$cpu_percent" ] && [ $cpu_percent -gt 30 ]; then
    # 构建进度条（20 格）
    filled=$((cpu_percent / 5))
    empty=$((20 - filled))
    bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    # CPU 颜色
    if [ $cpu_percent -lt 50 ]; then
        cpu_color=$FG_GREEN
    elif [ $cpu_percent -lt 80 ]; then
        cpu_color=$FG_YELLOW
    else
        cpu_color=$FG_MAGENTA
    fi

    output+="${FG_GRAY}|${RESET}  ${cpu_color}[${bar}]${RESET} ${DIM}${cpu_percent}%%${RESET}"
fi

# 可选：目录名（如果不是当前目录就显示）
if [ "$dir_name" != "$(basename $HOME)" ] && [ "$dir_name" != "." ]; then
    output+="  ${FG_GRAY}|${RESET}  ${DIM}${dir_name}${RESET}"
fi

printf "$output"
