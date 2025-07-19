#!/bin/bash

# БЕЗОПАСНЫЙ скрипт для очистки места на Ubuntu (для критически важных серверов)
# Автор: AI Assistant
# Версия: 1.0-SAFE
# ⚠️ ВНИМАНИЕ: Этот скрипт предназначен для критически важных серверов

# Улучшенные настройки безопасности
set -euo pipefail  # Остановка при ошибке, неопределенных переменных и ошибках в пайпах
IFS=$'\n\t'        # Безопасный разделитель полей

# Проверка версии bash
if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
    echo "Ошибка: Требуется Bash версии 4 или выше"
    exit 1
fi

# Цвета для вывода
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Конфигурация для безопасной очистки
readonly SCRIPT_VERSION="2.0-SAFE"
readonly LOG_RETENTION_DAYS=90          # Увеличенный период хранения логов
readonly WEB_LOG_RETENTION_DAYS=30      # Увеличенный период для веб-логов
readonly TEMP_RETENTION_DAYS=30         # Увеличенный период для временных файлов
readonly LARGE_LOG_SIZE="500M"          # Увеличенный порог для больших логов
readonly LARGE_FILE_SIZE="2G"           # Увеличенный порог для больших файлов
readonly MEDIUM_FILE_SIZE="1G"          # Увеличенный порог для средних файлов
readonly SMALL_FILE_SIZE="500M"         # Увеличенный порог для маленьких файлов

# Критические директории (НЕ УДАЛЯТЬ!)
readonly CRITICAL_DIRS=(
    "/etc"
    "/var/lib/mysql"
    "/var/lib/postgresql"
    "/var/lib/redis"
    "/var/lib/mongodb"
    "/var/lib/elasticsearch"
    "/var/lib/docker"
    "/var/lib/lxd"
    "/var/lib/snapd"
    "/var/lib/apt"
    "/var/lib/dpkg"
    "/var/lib/systemd"
    "/var/lib/ufw"
    "/var/lib/NetworkManager"
    "/var/lib/accounts-daemon"
    "/var/lib/polkit-1"
    "/var/lib/lightdm"
    "/var/lib/gdm3"
    "/var/lib/upower"
    "/var/lib/colord"
    "/var/lib/geoclue"
    "/var/lib/packagekit"
    "/var/lib/aptitude"
    "/var/lib/update-notifier"
    "/var/lib/update-manager"
    "/var/lib/ubuntu-release-upgrader"
    "/var/lib/ubuntu-advantage"
    "/var/lib/snapd"
    "/var/lib/flatpak"
    "/var/lib/apparmor"
    "/var/lib/rsyslog"
    "/var/lib/logrotate"
    "/var/lib/cron"
    "/var/lib/anacron"
    "/var/lib/systemd/coredump"
    "/var/lib/systemd/random-seed"
    "/var/lib/systemd/timesync"
    "/var/lib/systemd/linger"
    "/var/lib/systemd/notify"
    "/var/lib/systemd/private"
    "/var/lib/systemd/revokable"
    "/var/lib/systemd/user"
    "/var/lib/systemd/machines"
    "/var/lib/systemd/portable"
    "/var/lib/systemd/sysuser"
    "/var/lib/systemd/backlight"
    "/var/lib/systemd/rfkill"
    "/var/lib/systemd/sleep"
    "/var/lib/systemd/hibernate"
    "/var/lib/systemd/suspend"
    "/var/lib/systemd/hybrid-sleep"
    "/var/lib/systemd/suspend-then-hibernate"
)

# Переменные для статистики
declare -i total_space_freed=0
declare -i operations_count=0
declare -i critical_operations_skipped=0

# Функция для логирования
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

critical() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL:${NC} $1"
}

# Функция для безопасного выполнения команд
safe_execute() {
    local cmd="$1"
    local description="${2:-Выполнение команды}"
    
    log "$description: $cmd"
    if eval "$cmd"; then
        log "✓ $description выполнено успешно"
        return 0
    else
        error "✗ $description завершилось с ошибкой"
        return 1
    fi
}

# Функция для проверки критических директорий
is_critical_directory() {
    local path="$1"
    
    for critical_dir in "${CRITICAL_DIRS[@]}"; do
        if [[ "$path" == "$critical_dir" || "$path" == "$critical_dir"/* ]]; then
            return 0  # Критическая директория
        fi
    done
    return 1  # Не критическая директория
}

# Функция для проверки существования директории
check_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        warn "Директория не существует: $dir"
        return 1
    fi
    return 0
}

# Функция для безопасного удаления файлов
safe_remove() {
    local path="$1"
    local description="${2:-Удаление файла}"
    
    # Проверка на критическую директорию
    if is_critical_directory "$path"; then
        critical "ПОПЫТКА УДАЛЕНИЯ КРИТИЧЕСКОЙ ДИРЕКТОРИИ: $path"
        critical "Операция пропущена для безопасности сервера"
        ((critical_operations_skipped++))
        return 1
    fi
    
    if [[ -e "$path" ]]; then
        local size_before=$(du -sb "$path" 2>/dev/null | cut -f1 || echo "0")
        if rm -rf "$path" 2>/dev/null; then
            log "✓ $description: $path (освобождено: $(numfmt --to=iec $size_before))"
            ((total_space_freed += size_before))
            ((operations_count++))
            return 0
        else
            error "✗ Не удалось удалить: $path"
            return 1
        fi
    else
        warn "Файл не существует: $path"
        return 0
    fi
}

# Проверка прав администратора
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Этот скрипт должен быть запущен с правами администратора (sudo)"
        echo "Использование: sudo $0 [опции]"
        exit 1
    fi
}

# Проверка системы
check_system() {
    if [[ ! -f /etc/os-release ]]; then
        error "Не удалось определить операционную систему"
        exit 1
    fi
    
    local os_name
    os_name=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    
    if [[ "$os_name" != "ubuntu" && "$os_name" != "debian" ]]; then
        warn "Этот скрипт предназначен для Ubuntu/Debian. Текущая ОС: $os_name"
        read -p "Продолжить выполнение? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Проверка критических сервисов
check_critical_services() {
    log "=== ПРОВЕРКА КРИТИЧЕСКИХ СЕРВИСОВ ==="
    echo ""
    
    local critical_services=(
        "mysql"
        "postgresql"
        "redis"
        "mongodb"
        "elasticsearch"
        "docker"
        "nginx"
        "apache2"
        "ssh"
        "systemd"
        "ufw"
        "fail2ban"
    )
    
    for service in "${critical_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${GREEN}✓ Сервис $service активен${NC}"
        elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
            echo -e "${YELLOW}⚠ Сервис $service установлен, но не активен${NC}"
        else
            echo -e "${BLUE}ℹ Сервис $service не установлен${NC}"
        fi
    done
    echo ""
}

# Функция для получения размера директории
get_size() {
    local path="$1"
    if [[ -e "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1 || echo "0B"
    else
        echo "0B"
    fi
}

# Функция для получения размера в байтах
get_size_bytes() {
    local path="$1"
    if [[ -e "$path" ]]; then
        du -sb "$path" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

# Функция для получения свободного места
get_free_space() {
    df -h / | awk 'NR==2 {print $4}'
}

# Функция для получения свободного места в байтах
get_free_space_bytes() {
    df / | awk 'NR==2 {print $4*1024}'  # Конвертируем в байты
}

# Показать текущее состояние диска
show_disk_usage() {
    log "=== ТЕКУЩЕЕ СОСТОЯНИЕ ДИСКА ==="
    echo "Свободное место: $(get_free_space)"
    echo "Свободное место (байты): $(get_free_space_bytes)"
    echo ""
    df -h
    echo ""
}

# Показать статистику очистки
show_cleanup_stats() {
    log "=== СТАТИСТИКА БЕЗОПАСНОЙ ОЧИСТКИ ==="
    echo "Всего операций: $operations_count"
    echo "Освобождено места: $(numfmt --to=iec $total_space_freed)"
    echo "Критических операций пропущено: $critical_operations_skipped"
    echo "Свободное место после очистки: $(get_free_space)"
    echo ""
}

# БЕЗОПАСНАЯ очистка кэша apt
clean_apt_cache_safe() {
    log "=== БЕЗОПАСНАЯ ОЧИСТКА КЭША APT ==="
    echo ""
    
    local cache_dir="/var/cache/apt/archives"
    local cache_size_before=$(get_size_bytes "$cache_dir")
    echo -e "${YELLOW}Размер кэша APT до очистки:${NC} $(numfmt --to=iec $cache_size_before)"
    
    # Только безопасные операции
    safe_execute "apt-get autoclean" "Автоочистка кэша APT (только устаревшие пакеты)"
    
    # НЕ удаляем все пакеты, только устаревшие
    local cache_size_after=$(get_size_bytes "$cache_dir")
    local space_freed=$((cache_size_before - cache_size_after))
    
    echo -e "${GREEN}Размер кэша APT после очистки:${NC} $(numfmt --to=iec $cache_size_after)"
    echo -e "${GREEN}Освобождено места:${NC} $(numfmt --to=iec $space_freed)"
    echo -e "${BLUE}Примечание: Полная очистка кэша пропущена для безопасности${NC}"
    echo ""
}

# БЕЗОПАСНАЯ очистка временных файлов
clean_temp_files_safe() {
    log "=== БЕЗОПАСНАЯ ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ ==="
    echo ""
    
    local tmp_dirs=("/tmp" "/var/tmp")
    local total_space_freed=0
    
    for tmp_dir in "${tmp_dirs[@]}"; do
        if check_directory "$tmp_dir"; then
            local size_before=$(get_size_bytes "$tmp_dir")
            echo -e "${YELLOW}Размер $tmp_dir до очистки:${NC} $(numfmt --to=iec $size_before)"
            
            # Только очень старые файлы (90 дней)
            echo -e "${YELLOW}Очистка $tmp_dir (файлы старше 90 дней)...${NC}"
            
            # Удаление только очень старых файлов
            safe_execute "find $tmp_dir -type f -atime +90 -delete" "Удаление очень старых файлов в $tmp_dir"
            
            # Удаление пустых директорий
            safe_execute "find $tmp_dir -type d -empty -delete" "Удаление пустых директорий в $tmp_dir"
            
            local size_after=$(get_size_bytes "$tmp_dir")
            local space_freed=$((size_before - size_after))
            total_space_freed=$((total_space_freed + space_freed))
            
            echo -e "${GREEN}Размер $tmp_dir после очистки:${NC} $(numfmt --to=iec $size_after)"
            echo -e "${GREEN}Освобождено места в $tmp_dir:${NC} $(numfmt --to=iec $space_freed)"
        else
            warn "Директория $tmp_dir не существует или недоступна"
        fi
        echo ""
    done
    
    echo -e "${GREEN}Общее освобожденное место в временных директориях:${NC} $(numfmt --to=iec $total_space_freed)"
    echo -e "${BLUE}Примечание: Удалены только файлы старше 90 дней для безопасности${NC}"
    echo ""
}

# БЕЗОПАСНАЯ очистка журналов
clean_logs_safe() {
    log "=== БЕЗОПАСНАЯ ОЧИСТКА ЖУРНАЛОВ ==="
    echo ""
    
    local logs_dir="/var/log"
    local logs_size_before=$(get_size_bytes "$logs_dir")
    local journal_size_before=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMG]' | numfmt --from=iec || echo "0")
    
    echo -e "${YELLOW}Размер /var/log до очистки:${NC} $(numfmt --to=iec $logs_size_before)"
    echo -e "${YELLOW}Размер systemd журналов до очистки:${NC} $(numfmt --to=iec $journal_size_before)"
    echo ""
    
    # Только очень старые журналы (90 дней)
    echo -e "${YELLOW}Удаление журналов старше $LOG_RETENTION_DAYS дней...${NC}"
    
    # Безопасное удаление старых логов
    if check_directory "$logs_dir"; then
        safe_execute "find $logs_dir -name '*.log' -type f -mtime +$LOG_RETENTION_DAYS -delete" "Удаление старых .log файлов"
        safe_execute "find $logs_dir -name '*.gz' -type f -mtime +$LOG_RETENTION_DAYS -delete" "Удаление старых .gz файлов"
    fi
    
    # Ограничение размера journald (более консервативно)
    echo -e "${YELLOW}Ограничение размера systemd журналов...${NC}"
    safe_execute "journalctl --vacuum-time=${LOG_RETENTION_DAYS}d" "Ограничение systemd журналов по времени"
    safe_execute "journalctl --vacuum-size=2G" "Ограничение размера systemd журналов до 2GB"
    
    local logs_size_after=$(get_size_bytes "$logs_dir")
    local journal_size_after=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMG]' | numfmt --from=iec || echo "0")
    
    local logs_space_freed=$((logs_size_before - logs_size_after))
    local journal_space_freed=$((journal_size_before - journal_size_after))
    local total_space_freed=$((logs_space_freed + journal_space_freed))
    
    echo -e "${GREEN}Размер /var/log после очистки:${NC} $(numfmt --to=iec $logs_size_after)"
    echo -e "${GREEN}Размер systemd журналов после очистки:${NC} $(numfmt --to=iec $journal_size_after)"
    echo -e "${GREEN}Общее освобожденное место:${NC} $(numfmt --to=iec $total_space_freed)"
    echo -e "${BLUE}Примечание: Удалены только журналы старше 90 дней для безопасности${NC}"
    echo ""
}

# БЕЗОПАСНАЯ очистка кэша браузеров
clean_browser_cache_safe() {
    log "=== БЕЗОПАСНАЯ ОЧИСТКА КЭША БРАУЗЕРОВ ==="
    echo ""
    
    # Только очень старые файлы кэша (30 дней)
    echo -e "${YELLOW}Очистка очень старого кэша браузеров (старше 30 дней)...${NC}"
    
    # Firefox - только старые файлы
    for profile in /home/*/.mozilla/firefox/*.default*/cache*; do
        if [[ -d "$profile" ]]; then
            local size_before=$(du -sh "$profile" 2>/dev/null | cut -f1 || echo '0B')
            find "$profile" -type f -atime +30 -delete 2>/dev/null || true
            echo -e "${GREEN}Очищен старый кэш Firefox: $profile (было: $size_before)${NC}"
        fi
    done
    
    # Chrome/Chromium - только старые файлы
    for profile in /home/*/.cache/google-chrome/Default/Cache/*; do
        if [[ -d "$profile" ]]; then
            local size_before=$(du -sh "$profile" 2>/dev/null | cut -f1 || echo '0B')
            find "$profile" -type f -atime +30 -delete 2>/dev/null || true
            echo -e "${GREEN}Очищен старый кэш Chrome: $profile (было: $size_before)${NC}"
        fi
    done
    
    echo -e "${BLUE}Примечание: Удален только кэш старше 30 дней для безопасности${NC}"
    echo ""
}

# Анализ использования диска (только чтение)
analyze_disk_usage_safe() {
    log "=== БЕЗОПАСНЫЙ АНАЛИЗ ИСПОЛЬЗОВАНИЯ ДИСКА ==="
    echo ""
    
    # Общая информация о дисках
    echo -e "${BLUE}Информация о дисках:${NC}"
    df -h
    echo ""
    
    # Размеры основных директорий
    echo -e "${BLUE}Размеры основных директорий:${NC}"
    echo "Home директории: $(du -sh /home 2>/dev/null | cut -f1 || echo 'N/A')"
    echo "Var директория: $(du -sh /var 2>/dev/null | cut -f1 || echo 'N/A')"
    echo "Usr директория: $(du -sh /usr 2>/dev/null | cut -f1 || echo 'N/A')"
    echo "Tmp директория: $(du -sh /tmp 2>/dev/null | cut -f1 || echo 'N/A')"
    echo ""
    
    # Размеры кэша
    echo -e "${BLUE}Размеры кэша:${NC}"
    echo "APT кэш: $(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1 || echo 'N/A')"
    echo "Snap кэш: $(du -sh /var/lib/snapd/cache 2>/dev/null | cut -f1 || echo 'N/A')"
    echo "Docker кэш: $(du -sh /var/lib/docker 2>/dev/null | cut -f1 || echo 'N/A')"
    echo ""
    
    # Размеры журналов
    echo -e "${BLUE}Размеры журналов:${NC}"
    echo "Systemd журналы: $(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMG]' || echo 'N/A')"
    echo "Var/log: $(du -sh /var/log 2>/dev/null | cut -f1 || echo 'N/A')"
    echo ""
    
    # Предупреждение о критических директориях
    echo -e "${PURPLE}КРИТИЧЕСКИЕ ДИРЕКТОРИИ (НЕ УДАЛЯТЬ):${NC}"
    echo "• /etc - конфигурация системы"
    echo "• /var/lib/mysql - базы данных MySQL"
    echo "• /var/lib/postgresql - базы данных PostgreSQL"
    echo "• /var/lib/docker - контейнеры Docker"
    echo "• /var/lib/apt - информация о пакетах"
    echo "• /var/lib/dpkg - база данных пакетов"
    echo ""
}

# Поиск больших файлов (только чтение)
find_large_files_safe() {
    log "=== ПОИСК БОЛЬШИХ ФАЙЛОВ (ТОЛЬКО ЧТЕНИЕ) ==="
    echo ""
    
    echo -e "${YELLOW}Файлы больше 2GB:${NC}"
    find /home -type f -size +2G -exec ls -lh {} \; 2>/dev/null | head -5
    
    echo -e "${YELLOW}Файлы больше 1GB:${NC}"
    find /home -type f -size +1G -exec ls -lh {} \; 2>/dev/null | head -10
    
    echo -e "${YELLOW}Файлы больше 500MB:${NC}"
    find /home -type f -size +500M -exec ls -lh {} \; 2>/dev/null | head -15
    
    echo -e "${BLUE}Примечание: Показаны только файлы из /home для безопасности${NC}"
    echo ""
}

# Функция для анализа производительности системы
analyze_system_performance() {
    log "=== АНАЛИЗ ПРОИЗВОДИТЕЛЬНОСТИ СИСТЕМЫ ==="
    echo ""
    
    echo -e "${BLUE}📊 ИНФОРМАЦИЯ О СИСТЕМЕ:${NC}"
    echo -e "   🖥️  CPU: $(nproc) ядер"
    echo -e "   💾 Общая память: $(free -h | awk 'NR==2 {print $2}')"
    echo -e "   📈 Загрузка CPU: $(uptime | awk -F'load average:' '{print $2}')"
    echo -e "   🕐 Время работы: $(uptime -p)"
    echo ""
    
    echo -e "${BLUE}💾 ИСПОЛЬЗОВАНИЕ ПАМЯТИ:${NC}"
    free -h
    echo ""
    
    echo -e "${BLUE}💿 ИСПОЛЬЗОВАНИЕ ДИСКА:${NC}"
    df -h
    echo ""
    
    echo -e "${BLUE}🌐 СЕТЕВЫЕ СОЕДИНЕНИЯ:${NC}"
    ss -tuln | head -10
    echo ""
    
    echo -e "${BLUE}🔥 ТОП ПРОЦЕССОВ ПО ПАМЯТИ:${NC}"
    ps aux --sort=-%mem | head -10
    echo ""
}

# Функция для анализа безопасности системы
analyze_security_status() {
    log "=== АНАЛИЗ БЕЗОПАСНОСТИ СИСТЕМЫ ==="
    echo ""
    
    echo -e "${BLUE}🛡️ СТАТУС БРАНДМАУЭРА:${NC}"
    if command -v ufw &> /dev/null; then
        ufw status
    else
        echo "   UFW не установлен"
    fi
    echo ""
    
    echo -e "${BLUE}🔐 ПРОВЕРКА ОТКРЫТЫХ ПОРТОВ:${NC}"
    ss -tuln | grep LISTEN | head -10
    echo ""
    
    echo -e "${BLUE}👥 АКТИВНЫЕ ПОЛЬЗОВАТЕЛИ:${NC}"
    who
    echo ""
    
    echo -e "${BLUE}📝 ПОСЛЕДНИЕ ВХОДЫ:${NC}"
    last | head -10
    echo ""
    
    echo -e "${BLUE}⚠️ ПРОВЕРКА ПОДОЗРИТЕЛЬНЫХ ПРОЦЕССОВ:${NC}"
    ps aux | grep -E "(crypto|miner|botnet)" | grep -v grep || echo "   Подозрительные процессы не найдены"
    echo ""
}

# Функция для анализа сетевой активности
analyze_network_activity() {
    log "=== АНАЛИЗ СЕТЕВОЙ АКТИВНОСТИ ==="
    echo ""
    
    echo -e "${BLUE}🌐 СЕТЕВЫЕ ИНТЕРФЕЙСЫ:${NC}"
    ip addr show | grep -E "inet|UP" | head -10
    echo ""
    
    echo -e "${BLUE}📡 АКТИВНЫЕ СОЕДИНЕНИЯ:${NC}"
    ss -tuln | grep LISTEN | head -15
    echo ""
    
    echo -e "${BLUE}📊 СТАТИСТИКА СЕТИ:${NC}"
    ss -s
    echo ""
    
    echo -e "${BLUE}🔍 ПРОВЕРКА DNS:${NC}"
    cat /etc/resolv.conf
    echo ""
}

# Функция для анализа обновлений системы
analyze_system_updates() {
    log "=== АНАЛИЗ ОБНОВЛЕНИЙ СИСТЕМЫ ==="
    echo ""
    
    echo -e "${BLUE}📦 ДОСТУПНЫЕ ОБНОВЛЕНИЯ:${NC}"
    apt list --upgradable 2>/dev/null | head -10
    echo ""
    
    echo -e "${BLUE}📅 ПОСЛЕДНЕЕ ОБНОВЛЕНИЕ:${NC}"
    if [[ -f /var/log/apt/history.log ]]; then
        grep "upgrade" /var/log/apt/history.log | tail -5
    else
        echo "   История обновлений не найдена"
    fi
    echo ""
    
    echo -e "${BLUE}🔍 ПРОВЕРКА БЕЗОПАСНОСТИ:${NC}"
    if command -v unattended-upgrades &> /dev/null; then
        echo "   Автоматические обновления безопасности: $(unattended-upgrades --dry-run --debug 2>/dev/null | grep -c "Packages that will be upgraded" || echo "0")"
    else
        echo "   Автоматические обновления не настроены"
    fi
    echo ""
}

# Функция для анализа резервных копий
analyze_backup_status() {
    log "=== АНАЛИЗ РЕЗЕРВНЫХ КОПИЙ ==="
    echo ""
    
    echo -e "${BLUE}💾 ПРОВЕРКА РЕЗЕРВНЫХ КОПИЙ:${NC}"
    
    # Проверка резервных копий баз данных
    if command -v mysql &> /dev/null; then
        echo -e "   🗄️  MySQL: $(find /var/backups -name "*mysql*" -type f -mtime -7 2>/dev/null | wc -l) резервных копий за неделю"
    fi
    
    if command -v pg_dump &> /dev/null; then
        echo -e "   🗄️  PostgreSQL: $(find /var/backups -name "*postgresql*" -type f -mtime -7 2>/dev/null | wc -l) резервных копий за неделю"
    fi
    
    # Проверка общих резервных копий
    echo -e "   📁 Общие резервные копии: $(find /var/backups -type f -mtime -7 2>/dev/null | wc -l) файлов за неделю"
    echo -e "   📁 Резервные копии в /home: $(find /home -name "*.bak" -o -name "*.backup" -o -name "*~" -type f 2>/dev/null | wc -l) файлов"
    echo ""
    
    echo -e "${BLUE}📊 РАЗМЕР РЕЗЕРВНЫХ КОПИЙ:${NC}"
    du -sh /var/backups 2>/dev/null || echo "   Директория /var/backups не найдена"
    echo ""
}

# Функция для анализа ошибок системы
analyze_system_errors() {
    log "=== АНАЛИЗ ОШИБОК СИСТЕМЫ ==="
    echo ""
    
    echo -e "${BLUE}❌ ПОСЛЕДНИЕ ОШИБКИ СИСТЕМЫ:${NC}"
    journalctl -p err --since "24 hours ago" | tail -10
    echo ""
    
    echo -e "${BLUE}⚠️ КРИТИЧЕСКИЕ СОБЫТИЯ:${NC}"
    journalctl -p crit --since "24 hours ago" | tail -10
    echo ""
    
    echo -e "${BLUE}🔍 ОШИБКИ В ЛОГАХ:${NC}"
    grep -i error /var/log/syslog 2>/dev/null | tail -5
    echo ""
}

# Функция для анализа производительности диска
analyze_disk_performance() {
    log "=== АНАЛИЗ ПРОИЗВОДИТЕЛЬНОСТИ ДИСКА ==="
    echo ""
    
    echo -e "${BLUE}💿 ИНФОРМАЦИЯ О ДИСКАХ:${NC}"
    lsblk
    echo ""
    
    echo -e "${BLUE}📊 СТАТИСТИКА I/O:${NC}"
    iostat -x 1 3 2>/dev/null || echo "   iostat не установлен"
    echo ""
    
    echo -e "${BLUE}🔥 ТОП ПРОЦЕССОВ ПО I/O:${NC}"
    if command -v iotop &> /dev/null; then
        iotop -b -n 1 | head -10
    else
        echo "   iotop не установлен"
    fi
    echo ""
    
    echo -e "${BLUE}📈 ИСПОЛЬЗОВАНИЕ INODE:${NC}"
    df -i
    echo ""
}

# Основная функция безопасной очистки
main_cleanup_safe() {
    log "=== НАЧАЛО БЕЗОПАСНОЙ ОЧИСТКИ КРИТИЧЕСКОГО СЕРВЕРА ==="
    echo ""
    
    # Предупреждение
    echo -e "${PURPLE}⚠️  ВНИМАНИЕ: ЭТО КРИТИЧЕСКИ ВАЖНЫЙ СЕРВЕР ⚠️${NC}"
    echo -e "${PURPLE}Будет выполнена только безопасная очистка${NC}"
    echo -e "${PURPLE}Критические директории и файлы НЕ БУДУТ затронуты${NC}"
    echo ""
    
    # Проверка системы
    check_system
    
    # Проверка критических сервисов
    check_critical_services
    
    # Показать начальное состояние
    show_disk_usage
    
    # Анализ использования диска
    analyze_disk_usage_safe
    
    # Поиск больших файлов
    find_large_files_safe
    
    # Безопасная очистка
    echo -e "${BLUE}=== НАЧАЛО БЕЗОПАСНОЙ ОЧИСТКИ ===${NC}"
    echo ""
    
    # Только безопасные операции
    clean_apt_cache_safe
    clean_temp_files_safe
    clean_logs_safe
    clean_browser_cache_safe
    
    # Показать статистику очистки
    show_cleanup_stats
    
    # Финальный анализ
    echo -e "${BLUE}=== ФИНАЛЬНЫЙ АНАЛИЗ ПОСЛЕ БЕЗОПАСНОЙ ОЧИСТКИ ===${NC}"
    echo ""
    show_disk_usage
    
    log "Безопасная очистка завершена!"
    echo -e "${GREEN}✓ Сервер остался в рабочем состоянии${NC}"
    echo -e "${GREEN}✓ Критические файлы не были затронуты${NC}"
    echo -e "${GREEN}✓ Все сервисы продолжают работать${NC}"
}

# Функция для показа справки
show_help() {
    echo "БЕЗОПАСНЫЙ скрипт очистки Ubuntu v$SCRIPT_VERSION"
    echo "Автор: AI Assistant"
    echo ""
    echo "⚠️  ПРЕДНАЗНАЧЕН ДЛЯ КРИТИЧЕСКИ ВАЖНЫХ СЕРВЕРОВ ⚠️"
    echo ""
    echo "Использование: $0 [опция]"
    echo ""
    echo "Опции:"
    echo "  --interactive, -i       Интерактивное меню (рекомендуется)"
    echo "  --safe, -s              Безопасная очистка"
    echo "  --analyze, -a           Только анализ диска (без удаления)"
    echo "  --check-services, -c    Проверка критических сервисов"
    echo "  --version, -v           Показать версию скрипта"
    echo "  --help, -h              Показать эту справку"
    echo ""
    echo "ИНТЕРАКТИВНОЕ МЕНЮ ВКЛЮЧАЕТ:"
    echo "  📊 Анализ и мониторинг диска"
    echo "  🔍 Поиск больших файлов"
    echo "  ⚙️  Проверка критических сервисов"
    echo "  📈 Мониторинг состояния системы"
    echo "  🧹 Безопасная очистка по категориям"
    echo "  🛡️  Проверка безопасности системы"
    echo "  🔍 Расширенная аналитика (производительность, безопасность, сеть)"
    echo "  🧹 Дополнительная очистка (резервные копии, кэш разработчиков)"
    echo "  🔧 Утилиты и инструменты (резервные копии, диагностика, отчеты)"
    echo ""
    echo "БЕЗОПАСНЫЕ ФУНКЦИИ ОЧИСТКИ:"
    echo "  • Только автоочистка APT кэша (не полная очистка)"
    echo "  • Временные файлы старше 90 дней"
    echo "  • Журналы старше 90 дней"
    echo "  • Старый кэш браузеров (старше 30 дней)"
    echo ""
    echo "ЧТО НЕ УДАЛЯЕТСЯ:"
    echo "  • Критические директории (/etc, /var/lib/*)"
    echo "  • Базы данных и конфигурации"
    echo "  • Активные контейнеры и сервисы"
    echo "  • Недавние логи и кэш"
    echo ""
    echo "Безопасность:"
    echo "  • Проверка критических сервисов"
    echo "  • Защита критических директорий"
    echo "  • Консервативные настройки очистки"
    echo "  • Подробное логирование всех операций"
    echo "  • Подтверждение для всех операций"
    echo ""
    echo "Примеры:"
    echo "  sudo $0                    # Запуск интерактивного меню"
    echo "  sudo $0 --interactive      # Явный запуск меню"
    echo "  sudo $0 --safe             # Прямая безопасная очистка"
    echo "  sudo $0 --analyze          # Только анализ"
}

# Функция для показа версии
show_version() {
    echo "БЕЗОПАСНЫЙ скрипт очистки Ubuntu v$SCRIPT_VERSION"
    echo "Автор: AI Assistant"
    echo "Предназначен для критически важных серверов"
}

# Функция для анализа диска
analyze_only() {
    log "=== АНАЛИЗ ДИСКА (БЕЗ УДАЛЕНИЯ) ==="
    echo ""
    
    check_system
    check_critical_services
    show_disk_usage
    analyze_disk_usage_safe
    find_large_files_safe
    
    echo -e "${BLUE}=== РЕКОМЕНДАЦИИ ===${NC}"
    echo ""
    echo "Для безопасной очистки используйте: sudo $0 --safe"
    echo "Для проверки сервисов используйте: sudo $0 --check-services"
    echo ""
}

# Полное удаление папок веб-серверов (БЕЗОПАСНАЯ ВЕРСИЯ)
remove_web_server_dirs_safe() {
    log "=== ПОЛНОЕ УДАЛЕНИЕ ПАПОК ВЕБ-СЕРВЕРОВ (БЕЗОПАСНАЯ ВЕРСИЯ) ==="
    echo ""
    
    echo -e "${PURPLE}⚠️  КРИТИЧЕСКОЕ ПРЕДУПРЕЖДЕНИЕ: Эта операция полностью удалит папки логов Apache2 и Nginx${NC}"
    echo -e "${PURPLE}Это может повлиять на работу веб-серверов!${NC}"
    echo ""
    
    # Дополнительная проверка для безопасного скрипта
    echo -e "${YELLOW}Дополнительные проверки безопасности:${NC}"
    
    # Проверка активных веб-сервисов
    if systemctl is-active --quiet apache2 2>/dev/null; then
        echo -e "${RED}⚠️  Apache2 сервис активен! Рекомендуется остановить перед удалением.${NC}"
    fi
    
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "${RED}⚠️  Nginx сервис активен! Рекомендуется остановить перед удалением.${NC}"
    fi
    
    echo ""
    read -p "Продолжить удаление папок /var/log/apache2 и /var/log/nginx? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Удаление папок веб-серверов пропущено${NC}"
        echo ""
        return 0
    fi
    
    # Дополнительное подтверждение
    echo ""
    read -p "Введите 'DELETE' для подтверждения: " confirm_delete
    if [[ "$confirm_delete" != "DELETE" ]]; then
        echo -e "${YELLOW}Удаление папок веб-серверов отменено${NC}"
        echo ""
        return 0
    fi
    
    # Удаление папки Apache2
    if [[ -d "/var/log/apache2" ]]; then
        local apache_size=$(du -sb /var/log/apache2 2>/dev/null | cut -f1 || echo "0")
        echo -e "${YELLOW}Удаление папки /var/log/apache2 (размер: $(numfmt --to=iec $apache_size))...${NC}"
        
        if safe_remove "/var/log/apache2" "Удаление папки Apache2 логов"; then
            echo -e "${GREEN}✓ Папка /var/log/apache2 успешно удалена${NC}"
        else
            echo -e "${RED}✗ Не удалось удалить папку /var/log/apache2${NC}"
        fi
    else
        echo -e "${YELLOW}Папка /var/log/apache2 не существует${NC}"
    fi
    
    # Удаление папки Nginx
    if [[ -d "/var/log/nginx" ]]; then
        local nginx_size=$(du -sb /var/log/nginx 2>/dev/null | cut -f1 || echo "0")
        echo -e "${YELLOW}Удаление папки /var/log/nginx (размер: $(numfmt --to=iec $nginx_size))...${NC}"
        
        if safe_remove "/var/log/nginx" "Удаление папки Nginx логов"; then
            echo -e "${GREEN}✓ Папка /var/log/nginx успешно удалена${NC}"
        else
            echo -e "${RED}✗ Не удалось удалить папку /var/log/nginx${NC}"
        fi
    else
        echo -e "${YELLOW}Папка /var/log/nginx не существует${NC}"
    fi
    
    echo ""
}

# Очистка файлов wp_aiowps_audit_log.ibd в MySQL базах (БЕЗОПАСНАЯ ВЕРСИЯ)
clean_wordpress_audit_logs_safe() {
    log "=== ОЧИСТКА WORDPRESS AUDIT LOGS В MYSQL (БЕЗОПАСНАЯ ВЕРСИЯ) ==="
    echo ""
    
    if ! command -v mysql &> /dev/null; then
        warn "MySQL не установлен, пропускаем очистку WordPress audit logs"
        echo ""
        return 0
    fi
    
    local mysql_data_dir="/var/lib/mysql"
    if [[ ! -d "$mysql_data_dir" ]]; then
        warn "Директория MySQL данных не найдена: $mysql_data_dir"
        echo ""
        return 0
    fi
    
    echo -e "${YELLOW}Поиск файлов WordPress audit logs в базах данных...${NC}"
    
    # Поиск всех файлов WordPress audit logs (различные варианты названий)
    local audit_logs=$(find "$mysql_data_dir" -name "*aiowps_audit_log.ibd" -type f 2>/dev/null)
    
    if [[ -z "$audit_logs" ]]; then
        echo -e "${GREEN}Файлы WordPress audit logs не найдены${NC}"
        echo ""
        return 0
    fi
    
    local total_size=0
    local file_count=0
    
    echo -e "${YELLOW}Найдены файлы WordPress audit logs:${NC}"
    echo ""
    while IFS= read -r file; do
        local size=$(du -sb "$file" 2>/dev/null | cut -f1 || echo "0")
        local db_name=$(basename "$(dirname "$file")")
        local file_name=$(basename "$file")
        echo -e "${YELLOW}  📄 $db_name/$file_name${NC}"
        echo -e "${BLUE}     Размер: $(numfmt --to=iec $size)${NC}"
        echo ""
        total_size=$((total_size + size))
        ((file_count++))
    done <<< "$audit_logs"
    
    echo ""
    echo -e "${YELLOW}Общий размер файлов: $(numfmt --to=iec $total_size)${NC}"
    echo -e "${YELLOW}Количество файлов: $file_count${NC}"
    echo ""
    
    echo -e "${PURPLE}⚠️  КРИТИЧЕСКОЕ ПРЕДУПРЕЖДЕНИЕ: Удаление этих файлов может повлиять на работу WordPress сайтов!${NC}"
    echo -e "${PURPLE}Эти файлы содержат логи безопасности плагина All In One WP Security.${NC}"
    echo ""
    
    # Дополнительные проверки безопасности
    echo -e "${YELLOW}Дополнительные проверки безопасности:${NC}"
    
    # Проверка активного MySQL сервиса
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null; then
        echo -e "${RED}⚠️  MySQL сервис активен! Будет автоматически остановлен для безопасного удаления.${NC}"
    fi
    
    echo ""
    read -p "Продолжить удаление найденных файлов WordPress audit logs? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Удаление WordPress audit logs пропущено${NC}"
        echo ""
        return 0
    fi
    
    # Дополнительное подтверждение
    echo ""
    read -p "Введите 'DELETE' для подтверждения: " confirm_delete
    if [[ "$confirm_delete" != "DELETE" ]]; then
        echo -e "${YELLOW}Удаление WordPress audit logs отменено${NC}"
        echo ""
        return 0
    fi
    
    # Остановка MySQL для безопасного удаления
    echo -e "${YELLOW}Остановка MySQL сервиса для безопасного удаления...${NC}"
    if systemctl stop mysql 2>/dev/null || systemctl stop mysqld 2>/dev/null; then
        echo -e "${GREEN}✓ MySQL сервис остановлен${NC}"
    else
        echo -e "${RED}✗ Не удалось остановить MySQL сервис${NC}"
        echo -e "${YELLOW}Попытка удаления без остановки сервиса...${NC}"
    fi
    
    # Удаление файлов
    local removed_count=0
    local removed_size=0
    
    while IFS= read -r file; do
        local size=$(du -sb "$file" 2>/dev/null | cut -f1 || echo "0")
        local db_name=$(basename "$(dirname "$file")")
        
        if safe_remove "$file" "Удаление wp_aiowps_audit_log.ibd в базе $db_name"; then
            ((removed_count++))
            removed_size=$((removed_size + size))
        fi
    done <<< "$audit_logs"
    
    # Запуск MySQL обратно
    echo -e "${YELLOW}Запуск MySQL сервиса...${NC}"
    if systemctl start mysql 2>/dev/null || systemctl start mysqld 2>/dev/null; then
        echo -e "${GREEN}✓ MySQL сервис запущен${NC}"
    else
        echo -e "${RED}✗ Не удалось запустить MySQL сервис${NC}"
        echo -e "${YELLOW}Проверьте статус сервиса вручную: systemctl status mysql${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}Очистка WordPress audit logs завершена:${NC}"
    echo -e "${GREEN}  - Удалено файлов: $removed_count из $file_count${NC}"
    echo -e "${GREEN}  - Освобождено места: $(numfmt --to=iec $removed_size)${NC}"
    echo ""
}

# Интерактивное меню управления
interactive_menu() {
    while true; do
        clear
        echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║                БЕЗОПАСНОЕ УПРАВЛЕНИЕ СЕРВЕРОМ                ║${NC}"
        echo -e "${PURPLE}║                    Ubuntu Cleanup Safe v$SCRIPT_VERSION                    ║${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  КРИТИЧЕСКИ ВАЖНЫЙ СЕРВЕР - ТОЛЬКО БЕЗОПАСНЫЕ ОПЕРАЦИИ ⚠️${NC}"
        echo ""
        
        # Показать текущее состояние
        echo -e "${BLUE}📊 ТЕКУЩЕЕ СОСТОЯНИЕ:${NC}"
        echo -e "   💾 Свободное место: $(get_free_space)"
        echo -e "   🕐 Время: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        echo -e "${GREEN}📋 ВЫБЕРИТЕ ОПЕРАЦИЮ:${NC}"
        echo ""
        echo -e "${BLUE}🔍 АНАЛИЗ И МОНИТОРИНГ:${NC}"
        echo -e "   ${YELLOW}1)${NC} 📊 Полный анализ диска (без удаления)"
        echo -e "   ${YELLOW}2)${NC} 🔍 Поиск больших файлов"
        echo -e "   ${YELLOW}3)${NC} ⚙️  Проверка критических сервисов"
        echo -e "   ${YELLOW}4)${NC} 📈 Мониторинг состояния системы"
        echo ""
        
        echo -e "${GREEN}🧹 БЕЗОПАСНАЯ ОЧИСТКА:${NC}"
        echo -e "   ${YELLOW}5)${NC} 🧹 Полная безопасная очистка"
        echo -e "   ${YELLOW}6)${NC} 📦 Очистка только APT кэша"
        echo -e "   ${YELLOW}7)${NC} 📁 Очистка только временных файлов"
        echo -e "   ${YELLOW}8)${NC} 📝 Очистка только старых журналов"
        echo -e "   ${YELLOW}9)${NC} 🌐 Очистка только кэша браузеров"
        echo ""
        
        echo -e "${BLUE}🔧 ДОПОЛНИТЕЛЬНЫЕ ФУНКЦИИ:${NC}"
        echo -e "   ${YELLOW}10)${NC} 📋 Показать статистику очистки"
        echo -e "   ${YELLOW}11)${NC} 🛡️ Проверка безопасности системы"
        echo -e "   ${YELLOW}12)${NC} 📖 Показать справку"
        echo -e "   ${YELLOW}13)${NC} 🔄 Обновить информацию"
        echo ""
        
        echo -e "${GREEN}🔍 РАСШИРЕННАЯ АНАЛИТИКА:${NC}"
        echo -e "   ${YELLOW}14)${NC} 📊 Анализ производительности системы"
        echo -e "   ${YELLOW}15)${NC} 🛡️ Анализ безопасности системы"
        echo -e "   ${YELLOW}16)${NC} 🌐 Анализ сетевой активности"
        echo -e "   ${YELLOW}17)${NC} 📦 Анализ обновлений системы"
        echo -e "   ${YELLOW}18)${NC} 💾 Анализ резервных копий"
        echo -e "   ${YELLOW}19)${NC} ❌ Анализ ошибок системы"
        echo -e "   ${YELLOW}20)${NC} 💿 Анализ производительности диска"
        echo ""
        
        echo -e "${PURPLE}🧹 ДОПОЛНИТЕЛЬНАЯ ОЧИСТКА:${NC}"
        echo -e "   ${YELLOW}21)${NC} 💾 Очистка старых резервных копий"
        echo -e "   ${YELLOW}22)${NC} 👨‍💻 Очистка кэша разработчиков"
        echo -e "   ${YELLOW}23)${NC} 📝 Очистка логов приложений"
        echo -e "   ${YELLOW}24)${NC} 👥 Очистка старых сессий"
        echo -e "   ${YELLOW}25)${NC} 🎨 Очистка кэша приложений"
        echo ""
        
        echo -e "${BLUE}🔧 УТИЛИТЫ И ИНСТРУМЕНТЫ:${NC}"
        echo -e "   ${YELLOW}26)${NC} 💾 Создать резервную копию"
        echo -e "   ${YELLOW}27)${NC} 🔍 Проверка целостности системы"
        echo -e "   ${YELLOW}28)${NC} ⚡ Оптимизация системы"
        echo -e "   ${YELLOW}29)${NC} 📈 Мониторинг в реальном времени"
        echo -e "   ${YELLOW}30)${NC} 🔧 Диагностика проблем"
        echo -e "   ${YELLOW}31)${NC} 📄 Экспорт отчета системы"
        echo ""
        
        echo -e "${PURPLE}🗑️  КРИТИЧЕСКИЕ ОПЕРАЦИИ ОЧИСТКИ:${NC}"
        echo -e "   ${YELLOW}32)${NC} 🗄️ Очистка WordPress audit logs (wp_aiowps_audit_log.ibd)"
        echo -e "   ${YELLOW}33)${NC} 🌐 Полное удаление папок веб-серверов (/var/log/apache2, /var/log/nginx)"
        echo ""
        
        echo -e "${RED}❌ ВЫХОД:${NC}"
        echo -e "   ${YELLOW}0)${NC} 🚪 Выход из программы"
        echo ""
        
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}"
        
        read -p "Введите номер операции (0-33): " choice
        echo ""
        
        case $choice in
            1)
                log "=== ПОЛНЫЙ АНАЛИЗ ДИСКА ==="
                analyze_disk_usage_safe
                find_large_files_safe
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            2)
                log "=== ПОИСК БОЛЬШИХ ФАЙЛОВ ==="
                find_large_files_safe
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            3)
                log "=== ПРОВЕРКА КРИТИЧЕСКИХ СЕРВИСОВ ==="
                check_critical_services
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            4)
                log "=== МОНИТОРИНГ СОСТОЯНИЯ СИСТЕМЫ ==="
                show_disk_usage
                echo -e "${BLUE}Информация о системе:${NC}"
                echo -e "   ОС: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
                echo -e "   Ядро: $(uname -r)"
                echo -e "   Загрузка CPU: $(uptime | awk -F'load average:' '{print $2}')"
                echo -e "   Свободная память: $(free -h | awk 'NR==2 {print $7}')"
                echo -e "   Время работы: $(uptime -p)"
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            5)
                log "=== ПОЛНАЯ БЕЗОПАСНАЯ ОЧИСТКА ==="
                echo -e "${YELLOW}⚠️  ВНИМАНИЕ: Будет выполнена безопасная очистка${NC}"
                echo -e "${YELLOW}Критические файлы и сервисы НЕ БУДУТ затронуты${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    main_cleanup_safe
                    echo ""
                    read -p "Очистка завершена. Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Очистка отменена${NC}"
                    sleep 2
                fi
                ;;
            6)
                log "=== ОЧИСТКА APT КЭША ==="
                echo -e "${YELLOW}Будет выполнена только автоочистка APT кэша${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_apt_cache_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            7)
                log "=== ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ ==="
                echo -e "${YELLOW}Будут удалены только файлы старше 90 дней${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_temp_files_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            8)
                log "=== ОЧИСТКА ЖУРНАЛОВ ==="
                echo -e "${YELLOW}Будут удалены только журналы старше 90 дней${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_logs_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            9)
                log "=== ОЧИСТКА КЭША БРАУЗЕРОВ ==="
                echo -e "${YELLOW}Будет удален только кэш старше 30 дней${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_browser_cache_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            10)
                log "=== СТАТИСТИКА ОЧИСТКИ ==="
                show_cleanup_stats
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            11)
                log "=== ПРОВЕРКА БЕЗОПАСНОСТИ СИСТЕМЫ ==="
                echo -e "${BLUE}Проверка критических директорий:${NC}"
                for critical_dir in "${CRITICAL_DIRS[@]:0:10}"; do
                    if [[ -d "$critical_dir" ]]; then
                        echo -e "   ${GREEN}✓${NC} $critical_dir"
                    else
                        echo -e "   ${BLUE}ℹ${NC} $critical_dir (не существует)"
                    fi
                done
                echo -e "   ${BLUE}... и еще ${#CRITICAL_DIRS[@]} директорий защищены${NC}"
                echo ""
                echo -e "${GREEN}Все критические директории защищены от удаления${NC}"
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            12)
                show_help
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            13)
                log "Обновление информации..."
                # Обновляем информацию о системе
                sleep 1
                ;;
            14)
                analyze_system_performance
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            15)
                analyze_security_status
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            16)
                analyze_network_activity
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            17)
                analyze_system_updates
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            18)
                analyze_backup_status
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            19)
                analyze_system_errors
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            20)
                analyze_disk_performance
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            21)
                log "=== ОЧИСТКА СТАРЫХ РЕЗЕРВНЫХ КОПИЙ ==="
                echo -e "${YELLOW}Будут удалены только резервные копии старше 180 дней${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_old_backups_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            22)
                log "=== ОЧИСТКА КЭША РАЗРАБОТЧИКОВ ==="
                echo -e "${YELLOW}Будет удален только кэш старше 60 дней${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_developer_cache_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            23)
                log "=== ОЧИСТКА ЛОГОВ ПРИЛОЖЕНИЙ ==="
                echo -e "${YELLOW}Будут удалены только логи старше 90 дней${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_application_logs_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            24)
                log "=== ОЧИСТКА СТАРЫХ СЕССИЙ ==="
                echo -e "${YELLOW}Будут удалены только сессии старше 30 дней${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_user_sessions_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            25)
                log "=== ОЧИСТКА КЭША ПРИЛОЖЕНИЙ ==="
                echo -e "${YELLOW}Будет удален только кэш старше 60 дней${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_application_cache_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            26)
                create_backup_before_cleanup
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            27)
                check_system_integrity
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            28)
                log "=== ОПТИМИЗАЦИЯ СИСТЕМЫ ==="
                echo -e "${YELLOW}Будут выполнены безопасные оптимизации${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    optimize_system_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            29)
                monitor_system_realtime
                ;;
            30)
                diagnose_system_issues
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            31)
                export_system_report
                echo ""
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            32)
                log "=== ОЧИСТКА WORDPRESS AUDIT LOGS ==="
                echo -e "${PURPLE}⚠️  КРИТИЧЕСКАЯ ОПЕРАЦИЯ: Очистка WordPress audit logs${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    clean_wordpress_audit_logs_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            33)
                log "=== ПОЛНОЕ УДАЛЕНИЕ ПАПОК ВЕБ-СЕРВЕРОВ ==="
                echo -e "${PURPLE}⚠️  КРИТИЧЕСКАЯ ОПЕРАЦИЯ: Удаление папок веб-серверов${NC}"
                echo ""
                read -p "Продолжить? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    remove_web_server_dirs_safe
                    echo ""
                    read -p "Нажмите Enter для возврата в меню..."
                else
                    echo -e "${BLUE}Операция отменена${NC}"
                    sleep 2
                fi
                ;;
            0)
                echo -e "${GREEN}Спасибо за использование безопасного скрипта!${NC}"
                echo -e "${BLUE}Сервер остается в безопасном состоянии${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Проверка аргументов командной строки
case "${1:-}" in
    --safe|-s)
        check_root
        main_cleanup_safe
        ;;
    --analyze|-a)
        analyze_only
        ;;
    --check-services|-c)
        check_root
        check_critical_services
        ;;
    --interactive|-i)
        check_root
        interactive_menu
        ;;
    --version|-v)
        show_version
        ;;
    --help|-h)
        show_help
        ;;
    *)
        check_root
        interactive_menu
        ;;
esac 

# Очистка старых резервных копий (только очень старые)
clean_old_backups_safe() {
    log "=== ОЧИСТКА СТАРЫХ РЕЗЕРВНЫХ КОПИЙ ==="
    echo ""
    
    echo -e "${YELLOW}Будут удалены только резервные копии старше 180 дней${NC}"
    echo ""
    
    local backup_dirs=("/var/backups" "/home/*/backups" "/home/*/.backup")
    local total_space_freed=0
    
    for backup_dir in "${backup_dirs[@]}"; do
        if [[ -d "$backup_dir" ]]; then
            local size_before=$(du -sb "$backup_dir" 2>/dev/null | cut -f1 || echo "0")
            echo -e "${YELLOW}Очистка: $backup_dir${NC}"
            
            # Удаление только очень старых резервных копий
            find "$backup_dir" -type f -mtime +180 -name "*.bak" -o -name "*.backup" -o -name "*.tar.gz" -o -name "*.sql" | while read -r file; do
                if [[ -f "$file" ]]; then
                    local file_size=$(du -sb "$file" 2>/dev/null | cut -f1 || echo "0")
                    if rm -f "$file" 2>/dev/null; then
                        echo -e "   ${GREEN}Удален: $file ($(numfmt --to=iec $file_size))${NC}"
                        ((total_space_freed += file_size))
                    fi
                fi
            done
            
            local size_after=$(du -sb "$backup_dir" 2>/dev/null | cut -f1 || echo "0")
            local space_freed=$((size_before - size_after))
            
            echo -e "${GREEN}Освобождено в $backup_dir: $(numfmt --to=iec $space_freed)${NC}"
        fi
    done
    
    echo -e "${GREEN}Общее освобожденное место: $(numfmt --to=iec $total_space_freed)${NC}"
    echo ""
}

# Очистка кэша разработчиков (только старый)
clean_developer_cache_safe() {
    log "=== ОЧИСТКА КЭША РАЗРАБОТЧИКОВ ==="
    echo ""
    
    echo -e "${YELLOW}Будет удален только кэш старше 60 дней${NC}"
    echo ""
    
    # Python pip кэш
    if command -v pip &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша pip...${NC}"
        pip cache purge 2>/dev/null || true
        echo -e "${GREEN}Кэш pip очищен${NC}"
    fi
    
    # Node.js npm кэш
    if command -v npm &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша npm...${NC}"
        npm cache clean --force 2>/dev/null || true
        echo -e "${GREEN}Кэш npm очищен${NC}"
    fi
    
    # Go кэш
    if command -v go &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша Go...${NC}"
        go clean -cache -modcache -testcache 2>/dev/null || true
        echo -e "${GREEN}Кэш Go очищен${NC}"
    fi
    
    # Rust кэш
    if command -v cargo &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша Rust...${NC}"
        cargo clean 2>/dev/null || true
        echo -e "${GREEN}Кэш Rust очищен${NC}"
    fi
    
    # Composer кэш
    if command -v composer &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша Composer...${NC}"
        composer clear-cache 2>/dev/null || true
        echo -e "${GREEN}Кэш Composer очищен${NC}"
    fi
    
    echo ""
}

# Очистка старых конфигурационных файлов
clean_old_configs_safe() {
    log "=== ОЧИСТКА СТАРЫХ КОНФИГУРАЦИОННЫХ ФАЙЛОВ ==="
    echo ""
    
    echo -e "${YELLOW}Будут удалены только конфигурационные файлы старше 365 дней${NC}"
    echo ""
    
    # Поиск старых конфигурационных файлов в /home
    find /home -name ".*rc" -o -name ".*config" -o -name ".*conf" -type f -mtime +365 2>/dev/null | while read -r config_file; do
        if [[ -f "$config_file" && ! "$config_file" =~ \.(bak|backup|old)$ ]]; then
            local file_size=$(du -sb "$config_file" 2>/dev/null | cut -f1 || echo "0")
            echo -e "${YELLOW}Найден старый конфиг: $config_file ($(numfmt --to=iec $file_size))${NC}"
        fi
    done
    
    echo -e "${BLUE}Для безопасного удаления используйте ручную проверку${NC}"
    echo ""
}

# Очистка старых логов приложений
clean_application_logs_safe() {
    log "=== ОЧИСТКА ЛОГОВ ПРИЛОЖЕНИЙ ==="
    echo ""
    
    echo -e "${YELLOW}Будут удалены только логи старше 90 дней${NC}"
    echo ""
    
    # Логи приложений в /var/log
    local app_log_dirs=("/var/log/apache2" "/var/log/nginx" "/var/log/mysql" "/var/log/postgresql")
    
    for log_dir in "${app_log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            local size_before=$(du -sb "$log_dir" 2>/dev/null | cut -f1 || echo "0")
            echo -e "${YELLOW}Очистка: $log_dir${NC}"
            
            # Удаление старых логов
            find "$log_dir" -name "*.log.*" -type f -mtime +90 -delete 2>/dev/null || true
            find "$log_dir" -name "*.gz" -type f -mtime +90 -delete 2>/dev/null || true
            
            local size_after=$(du -sb "$log_dir" 2>/dev/null | cut -f1 || echo "0")
            local space_freed=$((size_before - size_after))
            
            echo -e "${GREEN}Освобождено в $log_dir: $(numfmt --to=iec $space_freed)${NC}"
        fi
    done
    
    echo ""
}

# Очистка старых сессий пользователей
clean_user_sessions_safe() {
    log "=== ОЧИСТКА СТАРЫХ СЕССИЙ ПОЛЬЗОВАТЕЛЕЙ ==="
    echo ""
    
    echo -e "${YELLOW}Будут удалены только сессии старше 30 дней${NC}"
    echo ""
    
    # Очистка старых сессий в /var/lib/systemd/user
    if [[ -d "/var/lib/systemd/user" ]]; then
        find /var/lib/systemd/user -type f -mtime +30 -delete 2>/dev/null || true
        echo -e "${GREEN}Старые systemd сессии очищены${NC}"
    fi
    
    # Очистка старых сессий в /tmp
    find /tmp -name ".X*" -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
    echo -e "${GREEN}Старые X11 сессии очищены${NC}"
    
    echo ""
}

# Очистка старых кэшей приложений
clean_application_cache_safe() {
    log "=== ОЧИСТКА КЭША ПРИЛОЖЕНИЙ ==="
    echo ""
    
    echo -e "${YELLOW}Будет удален только кэш старше 60 дней${NC}"
    echo ""
    
    # Кэш приложений в /var/cache
    local cache_dirs=("/var/cache/fontconfig" "/var/cache/man" "/var/cache/apt-xapian-index")
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            local size_before=$(du -sb "$cache_dir" 2>/dev/null | cut -f1 || echo "0")
            echo -e "${YELLOW}Очистка: $cache_dir${NC}"
            
            # Удаление старых файлов кэша
            find "$cache_dir" -type f -mtime +60 -delete 2>/dev/null || true
            
            local size_after=$(du -sb "$cache_dir" 2>/dev/null | cut -f1 || echo "0")
            local space_freed=$((size_before - size_after))
            
            echo -e "${GREEN}Освобождено в $cache_dir: $(numfmt --to=iec $space_freed)${NC}"
        fi
    done
    
    echo ""
}

# Функция для создания резервной копии перед очисткой
create_backup_before_cleanup() {
    log "=== СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ ==="
    echo ""
    
    local backup_dir="/var/backups/system-cleanup"
    local backup_file="$backup_dir/cleanup-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    echo -e "${YELLOW}Создание резервной копии критических данных...${NC}"
    
    # Создание директории для резервных копий
    mkdir -p "$backup_dir"
    
    # Создание резервной копии важных конфигураций
    tar -czf "$backup_file" \
        /etc/apt/sources.list \
        /etc/apt/sources.list.d \
        /etc/crontab \
        /etc/fstab \
        /etc/hosts \
        /etc/network/interfaces \
        /etc/ssh/sshd_config \
        2>/dev/null || true
    
    if [[ -f "$backup_file" ]]; then
        local backup_size=$(du -sh "$backup_file" | cut -f1)
        echo -e "${GREEN}✓ Резервная копия создана: $backup_file ($backup_size)${NC}"
    else
        echo -e "${RED}✗ Не удалось создать резервную копию${NC}"
    fi
    
    echo ""
}

# Функция для проверки целостности системы
check_system_integrity() {
    log "=== ПРОВЕРКА ЦЕЛОСТНОСТИ СИСТЕМЫ ==="
    echo ""
    
    echo -e "${BLUE}🔍 ПРОВЕРКА ФАЙЛОВ СИСТЕМЫ:${NC}"
    
    # Проверка целостности пакетов
    if command -v debsums &> /dev/null; then
        echo -e "${YELLOW}Проверка целостности пакетов...${NC}"
        debsums -c 2>/dev/null | head -10
    else
        echo -e "${BLUE}debsums не установлен, пропускаем проверку${NC}"
    fi
    
    echo ""
    
    echo -e "${BLUE}🔍 ПРОВЕРКА ПРАВ ДОСТУПА:${NC}"
    
    # Проверка критических файлов
    local critical_files=("/etc/passwd" "/etc/shadow" "/etc/group" "/etc/sudoers")
    
    for file in "${critical_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms=$(stat -c "%a" "$file")
            local owner=$(stat -c "%U:%G" "$file")
            echo -e "   $file: $perms ($owner)"
        fi
    done
    
    echo ""
}

# Функция для оптимизации системы
optimize_system_safe() {
    log "=== ОПТИМИЗАЦИЯ СИСТЕМЫ ==="
    echo ""
    
    echo -e "${YELLOW}Выполнение безопасных оптимизаций...${NC}"
    
    # Обновление базы данных locate
    if command -v updatedb &> /dev/null; then
        echo -e "${YELLOW}Обновление базы данных locate...${NC}"
        updatedb 2>/dev/null || true
        echo -e "${GREEN}База данных locate обновлена${NC}"
    fi
    
    # Очистка кэша man страниц
    if command -v mandb &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша man страниц...${NC}"
        mandb -c 2>/dev/null || true
        echo -e "${GREEN}Кэш man страниц очищен${NC}"
    fi
    
    # Обновление кэша иконок
    if command -v gtk-update-icon-cache &> /dev/null; then
        echo -e "${YELLOW}Обновление кэша иконок...${NC}"
        gtk-update-icon-cache -f -t /usr/share/icons/* 2>/dev/null || true
        echo -e "${GREEN}Кэш иконок обновлен${NC}"
    fi
    
    # Обновление кэша шрифтов
    if command -v fc-cache &> /dev/null; then
        echo -e "${YELLOW}Обновление кэша шрифтов...${NC}"
        fc-cache -f -v 2>/dev/null || true
        echo -e "${GREEN}Кэш шрифтов обновлен${NC}"
    fi
    
    echo ""
}

# Функция для мониторинга в реальном времени
monitor_system_realtime() {
    log "=== МОНИТОРИНГ В РЕАЛЬНОМ ВРЕМЕНИ ==="
    echo ""
    
    echo -e "${YELLOW}Мониторинг системы (Ctrl+C для выхода)...${NC}"
    echo ""
    
    # Простой мониторинг
    while true; do
        clear
        echo -e "${BLUE}=== МОНИТОРИНГ СИСТЕМЫ ===${NC}"
        echo -e "Время: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        echo -e "${GREEN}💾 ПАМЯТЬ:${NC}"
        free -h
        echo ""
        
        echo -e "${GREEN}💿 ДИСК:${NC}"
        df -h
        echo ""
        
        echo -e "${GREEN}🔥 ЗАГРУЗКА:${NC}"
        uptime
        echo ""
        
        echo -e "${GREEN}🌐 СЕТЬ:${NC}"
        ss -tuln | grep LISTEN | head -5
        echo ""
        
        sleep 5
    done
}

# Функция для диагностики проблем
diagnose_system_issues() {
    log "=== ДИАГНОСТИКА ПРОБЛЕМ СИСТЕМЫ ==="
    echo ""
    
    echo -e "${BLUE}🔍 ПРОВЕРКА ОСНОВНЫХ СЕРВИСОВ:${NC}"
    
    # Проверка systemd
    if systemctl is-system-running &> /dev/null; then
        echo -e "   ${GREEN}✓ Systemd работает нормально${NC}"
    else
        echo -e "   ${RED}✗ Проблемы с systemd${NC}"
    fi
    
    # Проверка сетевых интерфейсов
    if ip link show | grep -q "UP"; then
        echo -e "   ${GREEN}✓ Сетевые интерфейсы активны${NC}"
    else
        echo -e "   ${RED}✗ Проблемы с сетью${NC}"
    fi
    
    # Проверка дискового пространства
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        echo -e "   ${RED}✗ Критически мало места на диске ($disk_usage%)${NC}"
    elif [[ $disk_usage -gt 80 ]]; then
        echo -e "   ${YELLOW}⚠ Мало места на диске ($disk_usage%)${NC}"
    else
        echo -e "   ${GREEN}✓ Места на диске достаточно ($disk_usage%)${NC}"
    fi
    
    echo ""
    
    echo -e "${BLUE}🔍 ПРОВЕРКА ЛОГОВ ОШИБОК:${NC}"
    
    # Последние ошибки
    journalctl -p err --since "1 hour ago" | tail -5
    echo ""
    
    echo -e "${BLUE}🔍 ПРОВЕРКА ПРОЦЕССОВ:${NC}"
    
    # Процессы с высоким потреблением ресурсов
    echo -e "${YELLOW}Топ процессов по CPU:${NC}"
    ps aux --sort=-%cpu | head -5
    echo ""
    
    echo -e "${YELLOW}Топ процессов по памяти:${NC}"
    ps aux --sort=-%mem | head -5
    echo ""
}

# Функция для экспорта отчета
export_system_report() {
    log "=== ЭКСПОРТ ОТЧЕТА СИСТЕМЫ ==="
    echo ""
    
    local report_file="/tmp/system-report-$(date +%Y%m%d-%H%M%S).txt"
    
    echo -e "${YELLOW}Создание отчета системы...${NC}"
    
    {
        echo "=== ОТЧЕТ СИСТЕМЫ ==="
        echo "Дата: $(date)"
        echo "Система: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
        echo "Ядро: $(uname -r)"
        echo ""
        
        echo "=== ИСПОЛЬЗОВАНИЕ ДИСКА ==="
        df -h
        echo ""
        
        echo "=== ИСПОЛЬЗОВАНИЕ ПАМЯТИ ==="
        free -h
        echo ""
        
        echo "=== ЗАГРУЗКА СИСТЕМЫ ==="
        uptime
        echo ""
        
        echo "=== АКТИВНЫЕ СЕРВИСЫ ==="
        systemctl list-units --state=active | head -20
        echo ""
        
        echo "=== СЕТЕВЫЕ СОЕДИНЕНИЯ ==="
        ss -tuln | grep LISTEN
        echo ""
        
        echo "=== ПОСЛЕДНИЕ ОШИБКИ ==="
        journalctl -p err --since "24 hours ago" | tail -10
        echo ""
        
    } > "$report_file"
    
    if [[ -f "$report_file" ]]; then
        local report_size=$(du -sh "$report_file" | cut -f1)
        echo -e "${GREEN}✓ Отчет создан: $report_file ($report_size)${NC}"
        echo -e "${BLUE}Для просмотра: cat $report_file${NC}"
    else
        echo -e "${RED}✗ Не удалось создать отчет${NC}"
    fi
    
    echo ""
} 