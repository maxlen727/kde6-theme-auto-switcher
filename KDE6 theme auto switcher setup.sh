#!/bin/bash

set -e  # 出错时退出

echo "🚀 KDE 6 主题自动切换系统部署向导"
echo "====================================="
echo ""

# 获取用户自定义时间
get_user_time() {
    local prompt="$1"
    local default_time="$2"
    
    while true; do
        read -p "$prompt [$default_time]: " user_input
        user_input=${user_input:-$default_time}
        
        # 验证时间格式 (HH:MM)
        if [[ $user_input =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
            # 检查小时范围
            hour=$(echo $user_input | cut -d: -f1)
            minute=$(echo $user_input | cut -d: -f2)
            
            if [ $hour -ge 0 ] && [ $hour -le 23 ] && [ $minute -ge 0 ] && [ $minute -le 59 ]; then
                echo "$user_input"
                return 0
            fi
        fi
        
        echo "❌ 时间格式不正确，请使用 HH:MM 格式 (例如: 07:30)"
    done
}

# 获取用户偏好设置
echo "🔧 请设置主题切换时间："
LIGHT_TIME=$(get_user_time "亮色主题开始时间" "07:30")
DARK_TIME=$(get_user_time "暗色主题开始时间" "17:05")

echo ""
echo "📋 您的设置："
echo "   - 亮色主题时段：$DARK_TIME → $LIGHT_TIME"
echo "   - 暗色主题时段：$LIGHT_TIME → $DARK_TIME"
echo ""

read -p "确认设置？(y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ 部署已取消"
    exit 0
fi

echo ""

# 定义路径
LOCAL_BIN="$HOME/.local/bin"
AUTOSTART_DIR="$HOME/.config/autostart"
CONFIG_DIR="$HOME/.config/kde-theme-switcher"
CONFIG_FILE="$CONFIG_DIR/config.conf"

# 创建目录
mkdir -p "$LOCAL_BIN"
mkdir -p "$AUTOSTART_DIR"
mkdir -p "$CONFIG_DIR"

# 保存配置
cat > "$CONFIG_FILE" << EOF
# KDE 6 主题切换配置文件
LIGHT_THEME_START=$LIGHT_TIME
DARK_THEME_START=$DARK_TIME
LIGHT_GLOBAL_THEME=org.kde.breeze.desktop
DARK_GLOBAL_THEME=com.endeavouros.breezedarkeos.desktop
EOF

echo "💾 配置已保存到: $CONFIG_FILE"

# 写入调度脚本内容（优化版）
cat > "$LOCAL_BIN/kde6_theme_schedule.sh" << 'EOF'
#!/bin/bash

CONFIG_FILE="$HOME/.config/kde-theme-switcher/config.conf"

# 加载配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "❌ 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 解析时间
parse_time() {
    local time_str="$1"
    local hour=$(echo "$time_str" | cut -d: -f1)
    local minute=$(echo "$time_str" | cut -d: -f2)
    echo $((10#$hour * 60 + 10#$minute))
}

# 获取当前时间
now_hour=$(date +%H)
now_minute=$(date +%M)
now_total_min=$((10#$now_hour * 60 + 10#$now_minute))

# 解析配置的时间点
light_time_min=$(parse_time "$LIGHT_THEME_START")
dark_time_min=$(parse_time "$DARK_THEME_START")

# 确定下一个任务时间
if (( now_total_min < light_time_min )); then
    # 当前时间在午夜到亮色主题开始之间
    next_light_time="$LIGHT_THEME_START"
    next_dark_time="$DARK_THEME_START"
elif (( now_total_min < dark_time_min )); then
    # 当前时间在亮色主题时段
    next_light_time="tomorrow $LIGHT_THEME_START"
    next_dark_time="$DARK_THEME_START"
else
    # 当前时间在暗色主题时段
    next_light_time="$LIGHT_THEME_START"
    next_dark_time="tomorrow $DARK_THEME_START"
fi

# 安排任务
echo "$HOME/.local/bin/kde6_theme_switcher.sh light" | at -M $next_light_time 2>/dev/null || true
echo "$HOME/.local/bin/kde6_theme_switcher.sh dark" | at -M $next_dark_time 2>/dev/null || true

echo "⏰ 已安排主题切换任务："
echo "   - 亮色主题: $next_light_time"
echo "   - 暗色主题: $next_dark_time"
EOF

# 写入切换脚本内容（优化版）
cat > "$LOCAL_BIN/kde6_theme_switcher.sh" << 'EOF'
#!/bin/bash

THEME_MODE="$1"
CONFIG_FILE="$HOME/.config/kde-theme-switcher/config.conf"

# 加载配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "❌ 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

switch_to_light_theme() {
    echo "☀️ 切换到亮色主题"
    lookandfeeltool -a "$LIGHT_GLOBAL_THEME"
    qdbus6 org.kde.KWin /KWin reconfigure &> /dev/null || true
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshTheme &> /dev/null || true
}

switch_to_dark_theme() {
    echo "🌙 切换到暗色主题"
    lookandfeeltool -a "$DARK_GLOBAL_THEME"
    qdbus6 org.kde.KWin /KWin reconfigure &> /dev/null || true
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshTheme &> /dev/null || true
}

# 根据参数切换主题
case "$THEME_MODE" in
    "light")
        switch_to_light_theme
        ;;
    "dark")
        switch_to_dark_theme
        ;;
    *)
        # 自动判断模式（用于手动测试）
        current_hour=$(date +%H)
        current_minute=$(date +%M)
        current_total_min=$((10#$current_hour * 60 + 10#$current_minute))
        
        light_time_min=$((10#$(echo "$LIGHT_THEME_START" | cut -d: -f1) * 60 + 10#$(echo "$LIGHT_THEME_START" | cut -d: -f2)))
        dark_time_min=$((10#$(echo "$DARK_THEME_START" | cut -d: -f1) * 60 + 10#$(echo "$DARK_THEME_START" | cut -d: -f2)))
        
        if (( light_time_min <= dark_time_min )); then
            # 同一天内：light_time -> dark_time -> light_time(next day)
            if (( current_total_min >= light_time_min && current_total_min < dark_time_min )); then
                switch_to_light_theme
            else
                switch_to_dark_theme
            fi
        else
            # 跨天：dark_time -> light_time -> dark_time(next day)
            if (( current_total_min >= dark_time_min && current_total_min < light_time_min )); then
                switch_to_dark_theme
            else
                switch_to_light_theme
            fi
        fi
        ;;
esac

echo "✨ 主题切换完成"
EOF

# 添加可执行权限
chmod +x "$LOCAL_BIN/kde6_theme_schedule.sh"
chmod +x "$LOCAL_BIN/kde6_theme_switcher.sh"

# 创建 autostart .desktop 文件
cat > "$AUTOSTART_DIR/kde6_theme_scheduler.desktop" << EOF
[Desktop Entry]
Type=Application
Exec=$LOCAL_BIN/kde6_theme_schedule.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=KDE6 Theme Scheduler
Comment=Schedules automatic light/dark theme switching
EOF

echo "✅ 脚本文件已部署到 $LOCAL_BIN"
echo "✅ 自启动项已创建在 $AUTOSTART_DIR"

# 检查并安装 at 命令
echo "🔍 检查是否已安装 'at' 命令..."

if ! command -v at &> /dev/null; then
    echo "⚠️  'at' 命令未找到，正在尝试自动安装..."
    
    # 检测发行版类型并安装 at
    if command -v apt &> /dev/null; then
        echo "📦 检测到 Debian/Ubuntu 系统，使用 apt 安装..."
        if sudo apt update && sudo apt install -y at; then
            echo "✅ at 安装成功"
        else
            echo "❌ at 安装失败，请手动安装"
        fi
    elif command -v dnf &> /dev/null; then
        echo "📦 检测到 Fedora 系统，使用 dnf 安装..."
        if sudo dnf install -y at; then
            echo "✅ at 安装成功"
        else
            echo "❌ at 安装失败，请手动安装"
        fi
    elif command -v pacman &> /dev/null; then
        echo "📦 检测到 Arch 系统，使用 pacman 安装..."
        if sudo pacman -Sy --noconfirm at; then
            echo "✅ at 安装成功"
        else
            echo "❌ at 安装失败，请手动安装"
        fi
    else
        echo "❌ 无法识别的包管理器，请手动安装 'at' 命令"
        echo "   Debian/Ubuntu: sudo apt install at"
        echo "   Fedora:        sudo dnf install at"
        echo "   Arch:          sudo pacman -S at"
    fi
else
    echo "✅ 'at' 命令已安装"
fi

# 启用并启动 atd 服务
echo "🔧 检查并启动 atd 服务..."

if systemctl list-unit-files | grep -q atd.service; then
    if ! systemctl is-enabled atd &> /dev/null; then
        echo "🔌 启用 atd 服务..."
        sudo systemctl enable atd 2>/dev/null || echo "⚠️ 无法启用 atd 服务（可能需要 sudo 权限）"
    fi
    
    if ! systemctl is-active atd &> /dev/null; then
        echo "⚡ 启动 atd 服务..."
        sudo systemctl start atd 2>/dev/null || echo "⚠️ 无法启动 atd 服务（可能需要 sudo 权限）"
    else
        echo "✅ atd 服务已在运行"
    fi
else
    echo "⚠️ 系统中未找到 atd 服务，请手动检查"
fi

# 显示使用说明
echo ""
echo "🎉 部署完成！KDE 6 主题自动切换系统已配置完毕！"
echo ""
echo "📋 您的设置："
echo "   - 亮色主题开始时间: $LIGHT_TIME"
echo "   - 暗色主题开始时间: $DARK_TIME"
echo ""
echo "💡 使用说明："
echo "   - 系统将在每次启动时自动安排主题切换任务"
echo "   - 手动测试切换：$LOCAL_BIN/kde6_theme_switcher.sh"
echo "   - 手动安排任务：$LOCAL_BIN/kde6_theme_schedule.sh"
echo "   - 查看任务列表：atq"
echo "   - 清除所有任务：atrm \$(atq | awk '{print \$1}')"
echo "   - 修改时间设置：重新运行此部署脚本"
echo ""
echo "🔧 配置文件位置：$CONFIG_FILE"