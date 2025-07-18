#!/bin/bash

# Скрипт для очистки места на Ubuntu
# Автор: AI Assistant
# Версия: 1.1

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
readonly NC='\033[0m' # No Color

# Конфигурация
readonly SCRIPT_VERSION="2.0"
readonly LOG_RETENTION_DAYS=30
readonly WEB_LOG_RETENTION_DAYS=7
readonly TEMP_RETENTION_DAYS=7
readonly LARGE_LOG_SIZE="100M"
readonly LARGE_FILE_SIZE="1G"
readonly MEDIUM_FILE_SIZE="500M"
readonly SMALL_FILE_SIZE="100M"

# Переменные для статистики
declare -i total_space_freed=0
declare -i operations_count=0

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
    log "=== СТАТИСТИКА ОЧИСТКИ ==="
    echo "Всего операций: $operations_count"
    echo "Освобождено места: $(numfmt --to=iec $total_space_freed)"
    echo "Свободное место после очистки: $(get_free_space)"
    echo ""
}

# Очистка кэша apt
clean_apt_cache() {
    log "=== ОЧИСТКА КЭША APT ==="
    echo ""
    
    local cache_dir="/var/cache/apt/archives"
    local cache_size_before=$(get_size_bytes "$cache_dir")
    echo -e "${YELLOW}Размер кэша APT до очистки:${NC} $(numfmt --to=iec $cache_size_before)"
    
    # Очистка кэша APT
    safe_execute "apt-get clean" "Очистка кэша APT"
    safe_execute "apt-get autoclean" "Автоочистка кэша APT"
    
    # Очистка частичных загрузок
    if [[ -d "/var/cache/apt/archives/partial" ]]; then
        safe_execute "rm -rf /var/cache/apt/archives/partial/*" "Очистка частичных загрузок"
    fi
    
    local cache_size_after=$(get_size_bytes "$cache_dir")
    local space_freed=$((cache_size_before - cache_size_after))
    
    echo -e "${GREEN}Размер кэша APT после очистки:${NC} $(numfmt --to=iec $cache_size_after)"
    echo -e "${GREEN}Освобождено места:${NC} $(numfmt --to=iec $space_freed)"
    echo ""
}

# Удаление неиспользуемых пакетов
remove_unused_packages() {
    log "=== УДАЛЕНИЕ НЕИСПОЛЬЗУЕМЫХ ПАКЕТОВ ==="
    echo ""
    
    # Проверка доступного места перед удалением
    local free_space_before=$(get_free_space_bytes)
    echo -e "${YELLOW}Свободное место до очистки:${NC} $(numfmt --to=iec $free_space_before)"
    
    # Получить список неиспользуемых пакетов
    local unused_packages
    unused_packages=$(apt-get autoremove --dry-run 2>/dev/null | grep -E "^Remv|^Purg" | wc -l)
    echo -e "${YELLOW}Найдено неиспользуемых пакетов:${NC} $unused_packages"
    
    if [[ $unused_packages -gt 0 ]]; then
        safe_execute "apt-get autoremove -y" "Удаление неиспользуемых пакетов"
        safe_execute "apt-get autoremove --purge -y" "Удаление конфигурационных файлов неиспользуемых пакетов"
        
        # Очистка сломанных зависимостей
        safe_execute "apt-get --fix-broken install -y" "Исправление сломанных зависимостей"
        
        local free_space_after=$(get_free_space_bytes)
        local space_freed=$((free_space_after - free_space_before))
        
        echo -e "${GREEN}Свободное место после очистки:${NC} $(numfmt --to=iec $free_space_after)"
        echo -e "${GREEN}Освобождено места:${NC} $(numfmt --to=iec $space_freed)"
    else
        echo -e "${GREEN}Неиспользуемые пакеты не найдены${NC}"
    fi
    echo ""
}

# Очистка журналов системы
clean_logs() {
    log "=== ОЧИСТКА ЖУРНАЛОВ СИСТЕМЫ ==="
    echo ""
    
    local logs_dir="/var/log"
    local logs_size_before=$(get_size_bytes "$logs_dir")
    local journal_size_before=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMG]' | numfmt --from=iec || echo "0")
    
    echo -e "${YELLOW}Размер /var/log до очистки:${NC} $(numfmt --to=iec $logs_size_before)"
    echo -e "${YELLOW}Размер systemd журналов до очистки:${NC} $(numfmt --to=iec $journal_size_before)"
    echo ""
    
    # Очистка журналов старше установленного периода
    echo -e "${YELLOW}Удаление журналов старше $LOG_RETENTION_DAYS дней...${NC}"
    
    # Безопасное удаление старых логов
    if check_directory "$logs_dir"; then
        safe_execute "find $logs_dir -name '*.log' -type f -mtime +$LOG_RETENTION_DAYS -delete" "Удаление старых .log файлов"
        safe_execute "find $logs_dir -name '*.gz' -type f -mtime +$LOG_RETENTION_DAYS -delete" "Удаление старых .gz файлов"
        safe_execute "find $logs_dir -name '*.1' -type f -mtime +$LOG_RETENTION_DAYS -delete" "Удаление старых ротированных логов"
    fi
    
    # Очистка journald с ограничением размера
    echo -e "${YELLOW}Очистка systemd журналов...${NC}"
    safe_execute "journalctl --vacuum-time=${LOG_RETENTION_DAYS}d" "Очистка systemd журналов по времени"
    safe_execute "journalctl --vacuum-size=1G" "Ограничение размера systemd журналов"
    
    local logs_size_after=$(get_size_bytes "$logs_dir")
    local journal_size_after=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMG]' | numfmt --from=iec || echo "0")
    
    local logs_space_freed=$((logs_size_before - logs_size_after))
    local journal_space_freed=$((journal_size_before - journal_size_after))
    local total_space_freed=$((logs_space_freed + journal_space_freed))
    
    echo -e "${GREEN}Размер /var/log после очистки:${NC} $(numfmt --to=iec $logs_size_after)"
    echo -e "${GREEN}Размер systemd журналов после очистки:${NC} $(numfmt --to=iec $journal_size_after)"
    echo -e "${GREEN}Общее освобожденное место:${NC} $(numfmt --to=iec $total_space_freed)"
    echo ""
}

# Очистка логов веб-серверов
clean_web_logs() {
    log "=== ОЧИСТКА ЛОГОВ ВЕБ-СЕРВЕРОВ ==="
    echo ""
    
    # Apache логи
    if [[ -d "/var/log/apache2" ]]; then
        local apache_size_before=$(du -sh /var/log/apache2 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${YELLOW}Размер Apache логов до очистки:${NC} $apache_size_before"
        
        # Удаление старых логов Apache
        find /var/log/apache2 -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null || true
        find /var/log/apache2 -name "*.gz" -type f -mtime +7 -delete 2>/dev/null || true
        
        local apache_size_after=$(du -sh /var/log/apache2 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${GREEN}Размер Apache логов после очистки:${NC} $apache_size_after"
    fi
    
    # Nginx логи
    if [[ -d "/var/log/nginx" ]]; then
        local nginx_size_before=$(du -sh /var/log/nginx 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${YELLOW}Размер Nginx логов до очистки:${NC} $nginx_size_before"
        
        # Удаление старых логов Nginx
        find /var/log/nginx -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null || true
        find /var/log/nginx -name "*.gz" -type f -mtime +7 -delete 2>/dev/null || true
        
        local nginx_size_after=$(du -sh /var/log/nginx 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${GREEN}Размер Nginx логов после очистки:${NC} $nginx_size_after"
    fi
    
    echo ""
}

# Агрессивная очистка больших логов
clean_large_logs() {
    log "=== АГРЕССИВНАЯ ОЧИСТКА БОЛЬШИХ ЛОГОВ ==="
    echo ""
    
    echo -e "${YELLOW}Поиск и очистка больших логов (>100MB)...${NC}"
    
    # Найти большие логи и показать их
    local large_logs=$(find /var/log -type f -size +100M 2>/dev/null)
    
    if [[ -n "$large_logs" ]]; then
        echo -e "${YELLOW}Найдены большие логи:${NC}"
        echo "$large_logs" | while read -r log_file; do
            local size=$(du -h "$log_file" 2>/dev/null | cut -f1)
            echo -e "${YELLOW}  - $log_file ($size)${NC}"
        done
        
        echo ""
        read -p "Очистить эти логи? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "$large_logs" | while read -r log_file; do
                echo -e "${YELLOW}Очистка: $log_file${NC}"
                > "$log_file" 2>/dev/null || true
            done
            echo -e "${GREEN}Большие логи очищены${NC}"
        else
            echo -e "${YELLOW}Очистка больших логов пропущена${NC}"
        fi
    else
        echo -e "${GREEN}Большие логи не найдены${NC}"
    fi
    
    echo ""
}

# Очистка логов MySQL
clean_mysql_logs() {
    log "=== ОЧИСТКА ЛОГОВ MYSQL ==="
    echo ""
    
    if command -v mysql &> /dev/null; then
        local mysql_log_size_before=$(du -sh /var/log/mysql 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${YELLOW}Размер MySQL логов до очистки:${NC} $mysql_log_size_before"
        
        # Удаление старых логов MySQL
        find /var/log/mysql -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null || true
        find /var/log/mysql -name "*.gz" -type f -mtime +7 -delete 2>/dev/null || true
        
        local mysql_log_size_after=$(du -sh /var/log/mysql 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${GREEN}Размер MySQL логов после очистки:${NC} $mysql_log_size_after"
    else
        warn "MySQL не установлен, пропускаем очистку логов"
    fi
    echo ""
}

# Анализ баз данных MySQL
analyze_mysql_databases() {
    log "=== АНАЛИЗ БАЗ ДАННЫХ MYSQL ==="
    echo ""
    
    if command -v mysql &> /dev/null; then
        local mysql_data_size=$(du -sh /var/lib/mysql 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${YELLOW}Общий размер данных MySQL:${NC} $mysql_data_size"
        
        echo -e "${YELLOW}Размеры баз данных:${NC}"
        du -sh /var/lib/mysql/* 2>/dev/null | sort -hr | head -10
        
        echo ""
        echo -e "${YELLOW}Для оптимизации баз данных используйте:${NC}"
        echo "  - mysqlcheck -u root -p --optimize --all-databases"
        echo "  - mysqldump для создания резервных копий"
        echo "  - Удаление неиспользуемых баз данных"
    else
        warn "MySQL не установлен"
    fi
    echo ""
}

# Очистка временных файлов
clean_temp_files() {
    log "=== ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ ==="
    echo ""
    
    local tmp_dirs=("/tmp" "/var/tmp")
    local total_space_freed=0
    
    for tmp_dir in "${tmp_dirs[@]}"; do
        if check_directory "$tmp_dir"; then
            local size_before=$(get_size_bytes "$tmp_dir")
            echo -e "${YELLOW}Размер $tmp_dir до очистки:${NC} $(numfmt --to=iec $size_before)"
            
            # Очистка файлов старше установленного периода
            echo -e "${YELLOW}Очистка $tmp_dir (файлы старше $TEMP_RETENTION_DAYS дней)...${NC}"
            
            # Удаление старых файлов
            safe_execute "find $tmp_dir -type f -atime +$TEMP_RETENTION_DAYS -delete" "Удаление старых файлов в $tmp_dir"
            
            # Удаление пустых директорий
            safe_execute "find $tmp_dir -type d -empty -delete" "Удаление пустых директорий в $tmp_dir"
            
            # Удаление сломанных символических ссылок
            safe_execute "find $tmp_dir -type l -xtype l -delete" "Удаление сломанных символических ссылок в $tmp_dir"
            
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
    echo ""
}

# Очистка кэша браузеров
clean_browser_cache() {
    log "=== ОЧИСТКА КЭША БРАУЗЕРОВ ==="
    echo ""
    
    # Firefox
    echo -e "${YELLOW}Очистка кэша Firefox...${NC}"
    for profile in /home/*/.mozilla/firefox/*.default*/cache*; do
        if [[ -d "$profile" ]]; then
            local size_before=$(du -sh "$profile" 2>/dev/null | cut -f1 || echo '0B')
            rm -rf "$profile"/*
            echo -e "${GREEN}Очищен кэш Firefox: $profile (было: $size_before)${NC}"
        fi
    done
    
    # Chrome/Chromium
    echo -e "${YELLOW}Очистка кэша Chrome...${NC}"
    for profile in /home/*/.cache/google-chrome/Default/Cache/*; do
        if [[ -d "$profile" ]]; then
            local size_before=$(du -sh "$profile" 2>/dev/null | cut -f1 || echo '0B')
            rm -rf "$profile"/*
            echo -e "${GREEN}Очищен кэш Chrome: $profile (было: $size_before)${NC}"
        fi
    done
    
    echo -e "${YELLOW}Очистка кэша Chromium...${NC}"
    for profile in /home/*/.cache/chromium/Default/Cache/*; do
        if [[ -d "$profile" ]]; then
            local size_before=$(du -sh "$profile" 2>/dev/null | cut -f1 || echo '0B')
            rm -rf "$profile"/*
            echo -e "${GREEN}Очищен кэш Chromium: $profile (было: $size_before)${NC}"
        fi
    done
    
    echo ""
}

# Очистка кэша snap
clean_snap_cache() {
    log "=== ОЧИСТКА КЭША SNAP ==="
    echo ""
    
    if command -v snap &> /dev/null; then
        local snap_cache_size=$(du -sh /var/lib/snapd/cache 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${YELLOW}Размер кэша Snap до очистки:${NC} $snap_cache_size"
        
        # Установить количество сохраняемых версий
        snap set system refresh.retain=2
        
        # Очистить старые версии snap пакетов
        snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
            snap remove "$snapname" --revision="$revision" 2>/dev/null || true
        done
        
        local snap_cache_size_after=$(du -sh /var/lib/snapd/cache 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${GREEN}Размер кэша Snap после очистки:${NC} $snap_cache_size_after"
    else
        warn "Snap не установлен, пропускаем очистку"
    fi
    echo ""
}

# Очистка кэша Docker
clean_docker_cache() {
    log "=== ОЧИСТКА КЭША DOCKER ==="
    echo ""
    
    if command -v docker &> /dev/null; then
        local docker_size_before=$(du -sh /var/lib/docker 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${YELLOW}Размер Docker до очистки:${NC} $docker_size_before"
        
        echo -e "${YELLOW}Очистка неиспользуемых контейнеров, сетей и образов...${NC}"
        docker system prune -f
        
        echo -e "${YELLOW}Очистка неиспользуемых образов...${NC}"
        docker image prune -f
        
        echo -e "${YELLOW}Очистка неиспользуемых томов...${NC}"
        docker volume prune -f
        
        local docker_size_after=$(du -sh /var/lib/docker 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${GREEN}Размер Docker после очистки:${NC} $docker_size_after"
    else
        warn "Docker не установлен, пропускаем очистку"
    fi
    echo ""
}

# Очистка кэша LXD
clean_lxd_cache() {
    log "=== ОЧИСТКА КЭША LXD ==="
    echo ""
    
    if command -v lxc &> /dev/null; then
        local lxd_size_before=$(du -sh /var/lib/lxd 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${YELLOW}Размер LXD до очистки:${NC} $lxd_size_before"
        
        echo -e "${YELLOW}Очистка неиспользуемых образов LXD...${NC}"
        lxc image list | grep -v "|" | awk '{print $1}' | xargs -I {} lxc image delete {} 2>/dev/null || true
        
        local lxd_size_after=$(du -sh /var/lib/lxd 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${GREEN}Размер LXD после очистки:${NC} $lxd_size_after"
    else
        warn "LXD не установлен, пропускаем очистку"
    fi
    echo ""
}

# Очистка кэша VirtualBox
clean_virtualbox_cache() {
    log "=== ОЧИСТКА КЭША VIRTUALBOX ==="
    echo ""
    
    if command -v VBoxManage &> /dev/null; then
        local vbox_size_before=$(du -sh /var/lib/virtualbox 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${YELLOW}Размер VirtualBox до очистки:${NC} $vbox_size_before"
        
        echo -e "${YELLOW}Очистка неиспользуемых образов VirtualBox...${NC}"
        VBoxManage list hdds | grep -E "UUID|Location" | awk '/UUID/{uuid=$2} /Location/{print uuid, $2}' | while read uuid location; do
            if [[ ! -f "$location" ]]; then
                VBoxManage closemedium disk "$uuid" --delete 2>/dev/null || true
            fi
        done
        
        local vbox_size_after=$(du -sh /var/lib/virtualbox 2>/dev/null | cut -f1 || echo 'N/A')
        echo -e "${GREEN}Размер VirtualBox после очистки:${NC} $vbox_size_after"
    else
        warn "VirtualBox не установлен, пропускаем очистку"
    fi
    echo ""
}

# Очистка старых ядер
clean_old_kernels() {
    log "=== УДАЛЕНИЕ СТАРЫХ ЯДЕР ==="
    echo ""
    
    # Получить список установленных ядер
    local current_kernel
    current_kernel=$(uname -r)
    local installed_kernels
    installed_kernels=$(dpkg --list | grep linux-image | awk '/^ii/{ print $2 }')
    
    echo -e "${YELLOW}Текущее ядро:${NC} $current_kernel"
    echo -e "${YELLOW}Установленные ядра:${NC}"
    
    local old_kernels_found=false
    local kernels_to_remove=()
    
    # Собрать список ядер для удаления
    while IFS= read -r kernel; do
        if [[ -n "$kernel" ]]; then
            local kernel_version
            kernel_version=$(echo "$kernel" | sed 's/linux-image-//')
            if [[ "$kernel_version" != "$current_kernel" ]]; then
                echo -e "${YELLOW}  - Найдено старое ядро:${NC} $kernel_version"
                kernels_to_remove+=("$kernel")
                old_kernels_found=true
            else
                echo -e "${GREEN}  - Текущее ядро (оставляем):${NC} $kernel_version"
            fi
        fi
    done <<< "$installed_kernels"
    
    if [[ "$old_kernels_found" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}Найдено старых ядер для удаления:${NC} ${#kernels_to_remove[@]}"
        
        # Запросить подтверждение
        read -p "Удалить старые ядра? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            for kernel in "${kernels_to_remove[@]}"; do
                local kernel_version
                kernel_version=$(echo "$kernel" | sed 's/linux-image-//')
                echo -e "${YELLOW}Удаление ядра:${NC} $kernel_version"
                safe_execute "apt-get remove --purge -y $kernel" "Удаление ядра $kernel_version"
            done
            
            # Очистка конфигурационных файлов
            safe_execute "apt-get autoremove --purge -y" "Очистка конфигурационных файлов удаленных ядер"
            
            echo -e "${GREEN}Старые ядра удалены${NC}"
        else
            echo -e "${YELLOW}Удаление старых ядер пропущено${NC}"
        fi
    else
        echo -e "${GREEN}Старые ядра не найдены${NC}"
    fi
    echo ""
}

# Очистка корзины
clean_trash() {
    log "=== ОЧИСТКА КОРЗИНЫ ==="
    echo ""
    
    for user_home in /home/*; do
        if [[ -d "$user_home/.local/share/Trash" ]]; then
            local trash_size=$(du -sh "$user_home/.local/share/Trash" 2>/dev/null | cut -f1 || echo '0B')
            if [[ "$trash_size" != "0B" ]]; then
                echo -e "${YELLOW}Корзина пользователя $(basename $user_home):${NC} $trash_size"
                rm -rf "$user_home/.local/share/Trash"/*
                echo -e "${GREEN}Корзина очищена для пользователя: $(basename $user_home)${NC}"
            fi
        fi
    done
    echo ""
}

# Очистка кэша pip
clean_pip_cache() {
    log "=== ОЧИСТКА КЭША PIP ==="
    echo ""
    
    if command -v pip &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша pip...${NC}"
        pip cache purge 2>/dev/null || true
        echo -e "${GREEN}Кэш pip очищен${NC}"
    else
        warn "pip не установлен, пропускаем очистку"
    fi
    echo ""
}

# Очистка кэша conda
clean_conda_cache() {
    log "=== ОЧИСТКА КЭША CONDA ==="
    echo ""
    
    if command -v conda &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша conda...${NC}"
        conda clean --all --yes 2>/dev/null || true
        echo -e "${GREEN}Кэш conda очищен${NC}"
    else
        warn "conda не установлен, пропускаем очистку"
    fi
    echo ""
}

# Очистка кэша composer
clean_composer_cache() {
    log "=== ОЧИСТКА КЭША COMPOSER ==="
    echo ""
    
    if command -v composer &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша composer...${NC}"
        composer clear-cache 2>/dev/null || true
        echo -e "${GREEN}Кэш composer очищен${NC}"
    else
        warn "composer не установлен, пропускаем очистку"
    fi
    echo ""
}

# Очистка кэша npm
clean_npm_cache() {
    log "=== ОЧИСТКА КЭША NPM ==="
    echo ""
    
    if command -v npm &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша npm...${NC}"
        npm cache clean --force
        echo -e "${GREEN}Кэш npm очищен${NC}"
    else
        warn "npm не установлен, пропускаем очистку"
    fi
    echo ""
}

# Очистка кэша yarn
clean_yarn_cache() {
    log "=== ОЧИСТКА КЭША YARN ==="
    echo ""
    
    if command -v yarn &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша yarn...${NC}"
        yarn cache clean
        echo -e "${GREEN}Кэш yarn очищен${NC}"
    else
        warn "yarn не установлен, пропускаем очистку"
    fi
    echo ""
}

# Очистка кэша go
clean_go_cache() {
    log "=== ОЧИСТКА КЭША GO ==="
    echo ""
    
    if command -v go &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша go...${NC}"
        go clean -cache -modcache -testcache 2>/dev/null || true
        echo -e "${GREEN}Кэш go очищен${NC}"
    else
        warn "go не установлен, пропускаем очистку"
    fi
    echo ""
}

# Очистка кэша rust
clean_rust_cache() {
    log "=== ОЧИСТКА КЭША RUST ==="
    echo ""
    
    if command -v cargo &> /dev/null; then
        echo -e "${YELLOW}Очистка кэша rust...${NC}"
        cargo clean 2>/dev/null || true
        echo -e "${GREEN}Кэш rust очищен${NC}"
    else
        warn "rust не установлен, пропускаем очистку"
    fi
    echo ""
}

# Поиск больших файлов
find_large_files() {
    log "=== ПОИСК БОЛЬШИХ ФАЙЛОВ ==="
    echo ""
    
    echo -e "${YELLOW}Файлы больше 1GB:${NC}"
    find /home -type f -size +1G -exec ls -lh {} \; 2>/dev/null | head -10
    
    echo -e "${YELLOW}Файлы больше 500MB:${NC}"
    find /home -type f -size +500M -exec ls -lh {} \; 2>/dev/null | head -15
    
    echo -e "${YELLOW}Файлы больше 100MB:${NC}"
    find /home -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -20
    
    echo ""
}

# Поиск больших файлов в системных директориях
find_system_large_files() {
    log "=== ПОИСК БОЛЬШИХ ФАЙЛОВ В СИСТЕМНЫХ ДИРЕКТОРИЯХ ==="
    echo ""
    
    echo -e "${YELLOW}Большие файлы в /var/log:${NC}"
    find /var/log -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -10
    
    echo -e "${YELLOW}Большие файлы в /var/lib:${NC}"
    find /var/lib -type f -size +500M -exec ls -lh {} \; 2>/dev/null | head -10
    
    echo -e "${YELLOW}Большие файлы в /tmp:${NC}"
    find /tmp -type f -size +50M -exec ls -lh {} \; 2>/dev/null | head -10
    
    echo ""
}

# Анализ дублирующихся файлов
find_duplicate_files() {
    log "=== ПОИСК ДУБЛИРУЮЩИХСЯ ФАЙЛОВ ==="
    echo ""
    
    echo -e "${YELLOW}Поиск дублирующихся файлов в /home (может занять время)...${NC}"
    find /home -type f -size +10M -exec md5sum {} \; 2>/dev/null | sort | uniq -w32 -dD | head -20
    
    echo ""
}

# Поиск больших директорий
find_large_directories() {
    log "=== САМЫЕ БОЛЬШИЕ ДИРЕКТОРИИ ==="
    echo ""
    
    echo -e "${YELLOW}Самые большие директории в /home:${NC}"
    du -h /home 2>/dev/null | sort -hr | head -15
    
    echo -e "${YELLOW}Самые большие директории в /var:${NC}"
    du -h /var 2>/dev/null | sort -hr | head -10
    
    echo -e "${YELLOW}Самые большие директории в /usr:${NC}"
    du -h /usr 2>/dev/null | sort -hr | head -10
    
    echo ""
}

# Анализ использования диска
analyze_disk_usage() {
    log "=== АНАЛИЗ ИСПОЛЬЗОВАНИЯ ДИСКА ==="
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
}

# Основная функция очистки
main_cleanup() {
    log "=== НАЧАЛО ОЧИСТКИ СИСТЕМЫ UBUNTU ==="
    echo ""
    
    # Проверка системы
    check_system
    
    # Показать начальное состояние
    show_disk_usage
    
    # 1. Анализ использования диска
    analyze_disk_usage
    
    # 2. Поиск больших файлов и директорий
    find_large_files
    find_system_large_files
    find_large_directories
    
    # 3. Очистка по категориям
    echo -e "${BLUE}=== НАЧАЛО ОЧИСТКИ ПО КАТЕГОРИЯМ ===${NC}"
    echo ""
    
    # Кэш пакетов
    clean_apt_cache
    clean_snap_cache
    
    # Кэш контейнеров и виртуальных машин
    clean_docker_cache
    clean_lxd_cache
    clean_virtualbox_cache
    
    # Кэш браузеров
    clean_browser_cache
    
    # Кэш разработчиков
    clean_pip_cache
    clean_conda_cache
    clean_composer_cache
    clean_npm_cache
    clean_yarn_cache
    clean_go_cache
    clean_rust_cache
    
    # Мусор
    clean_trash
    clean_temp_files
    
    # Репозитории и пакеты
    remove_unused_packages
    clean_old_kernels
    
    # Журналы
    clean_logs
    clean_web_logs
    clean_mysql_logs
    
    # Обновить базу данных пакетов
    log "Обновление базы данных пакетов..."
    safe_execute "apt-get update" "Обновление базы данных пакетов"
    
    # Показать статистику очистки
    show_cleanup_stats
    
    # Финальный анализ
    echo -e "${BLUE}=== ФИНАЛЬНЫЙ АНАЛИЗ ПОСЛЕ ОЧИСТКИ ===${NC}"
    echo ""
    show_disk_usage
    
    log "Очистка завершена!"
}

# Функция для интерактивной очистки
interactive_cleanup() {
    echo -e "${BLUE}=== СКРИПТ ОЧИСТКИ UBUNTU ===${NC}"
    echo "Выберите действие:"
    echo "1) Полная очистка системы (рекомендуется)"
    echo "2) Только анализ диска и поиск больших файлов"
    echo "3) Очистка кэша пакетов (APT, Snap)"
    echo "4) Очистка кэша контейнеров (Docker, LXD, VirtualBox)"
    echo "5) Очистка кэша браузеров"
    echo "6) Очистка кэша разработчиков (pip, npm, yarn, go, rust)"
    echo "7) Очистка мусора (корзина, временные файлы)"
    echo "8) Очистка репозиториев (неиспользуемые пакеты, старые ядра)"
    echo "9) Очистка журналов (система, веб-серверы, MySQL)"
    echo "10) Агрессивная очистка больших логов"
    echo "11) Анализ баз данных MySQL"
    echo "12) Поиск дублирующихся файлов"
    echo "13) Показать использование диска"
    echo "0) Выход"
    echo ""
    
    read -p "Введите номер (0-13): " choice
    
    case $choice in
        1)
            main_cleanup
            ;;
        2)
            analyze_disk_usage
            find_large_files
            find_system_large_files
            find_large_directories
            ;;
        3)
            echo -e "${BLUE}=== ОЧИСТКА КЭША ПАКЕТОВ ===${NC}"
            echo ""
            clean_apt_cache
            clean_snap_cache
            ;;
        4)
            echo -e "${BLUE}=== ОЧИСТКА КЭША КОНТЕЙНЕРОВ ===${NC}"
            echo ""
            clean_docker_cache
            clean_lxd_cache
            clean_virtualbox_cache
            ;;
        5)
            echo -e "${BLUE}=== ОЧИСТКА КЭША БРАУЗЕРОВ ===${NC}"
            echo ""
            clean_browser_cache
            ;;
        6)
            echo -e "${BLUE}=== ОЧИСТКА КЭША РАЗРАБОТЧИКОВ ===${NC}"
            echo ""
            clean_pip_cache
            clean_conda_cache
            clean_composer_cache
            clean_npm_cache
            clean_yarn_cache
            clean_go_cache
            clean_rust_cache
            ;;
        7)
            echo -e "${BLUE}=== ОЧИСТКА МУСОРА ===${NC}"
            echo ""
            clean_trash
            clean_temp_files
            ;;
        8)
            echo -e "${BLUE}=== ОЧИСТКА РЕПОЗИТОРИЕВ ===${NC}"
            echo ""
            remove_unused_packages
            clean_old_kernels
            ;;
        9)
            echo -e "${BLUE}=== ОЧИСТКА ЖУРНАЛОВ ===${NC}"
            echo ""
            clean_logs
            clean_web_logs
            clean_mysql_logs
            ;;
        10)
            clean_large_logs
            ;;
        11)
            analyze_mysql_databases
            ;;
        12)
            find_duplicate_files
            ;;
        13)
            show_disk_usage
            ;;
        0)
            log "Выход из скрипта"
            exit 0
            ;;
        *)
            error "Неверный выбор"
            exit 1
            ;;
    esac
}

# Функция для показа справки
show_help() {
    echo "Скрипт очистки Ubuntu v$SCRIPT_VERSION"
    echo "Автор: AI Assistant"
    echo ""
    echo "Использование: $0 [опция]"
    echo ""
    echo "Опции:"
    echo "  --auto, -a              Автоматическая полная очистка"
    echo "  --interactive, -i       Интерактивная очистка"
    echo "  --dry-run, -d           Показать что будет очищено без выполнения"
    echo "  --version, -v           Показать версию скрипта"
    echo "  --help, -h              Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  sudo $0 --auto"
    echo "  sudo $0 --interactive"
    echo "  sudo $0 --dry-run"
    echo ""
    echo "Функции очистки:"
    echo "  • Кэш пакетов (APT, Snap)"
    echo "  • Кэш контейнеров (Docker, LXD, VirtualBox)"
    echo "  • Кэш браузеров (Firefox, Chrome, Chromium)"
    echo "  • Кэш разработчиков (pip, npm, yarn, go, rust)"
    echo "  • Временные файлы и корзина"
    echo "  • Неиспользуемые пакеты и старые ядра"
    echo "  • Системные журналы и логи веб-серверов"
    echo ""
    echo "Безопасность:"
    echo "  • Требуются права администратора"
    echo "  • Подтверждение для критических операций"
    echo "  • Подробное логирование всех операций"
    echo "  • Статистика освобожденного места"
}

# Функция для показа версии
show_version() {
    echo "Скрипт очистки Ubuntu v$SCRIPT_VERSION"
    echo "Автор: AI Assistant"
}

# Функция для сухой прогонки
dry_run() {
    log "=== РЕЖИМ СУХОЙ ПРОГОНКИ ==="
    echo "Этот режим покажет что будет очищено без выполнения операций"
    echo ""
    
    check_system
    show_disk_usage
    analyze_disk_usage
    
    echo -e "${BLUE}=== ЧТО БУДЕТ ОЧИЩЕНО ===${NC}"
    echo ""
    
    # Показать размеры кэшей
    echo "APT кэш: $(get_size /var/cache/apt/archives)"
    echo "Snap кэш: $(get_size /var/lib/snapd/cache)"
    echo "Docker: $(get_size /var/lib/docker)"
    echo "LXD: $(get_size /var/lib/lxd)"
    echo "Временные файлы: $(get_size /tmp) + $(get_size /var/tmp)"
    echo "Системные журналы: $(get_size /var/log)"
    echo "Корзина: $(get_size /home/*/.local/share/Trash 2>/dev/null || echo 'N/A')"
    echo ""
    
    # Показать неиспользуемые пакеты
    local unused_packages
    unused_packages=$(apt-get autoremove --dry-run 2>/dev/null | grep -E "^Remv|^Purg" | wc -l)
    echo "Неиспользуемых пакетов: $unused_packages"
    
    # Показать старые ядра
    local current_kernel
    current_kernel=$(uname -r)
    local old_kernels
    old_kernels=$(dpkg --list | grep linux-image | awk '/^ii/{ print $2 }' | grep -v "$current_kernel" | wc -l)
    echo "Старых ядер: $old_kernels"
    echo ""
    
    echo -e "${YELLOW}Для выполнения очистки используйте: sudo $0 --auto${NC}"
}

# Проверка аргументов командной строки
case "${1:-}" in
    --auto|-a)
        check_root
        main_cleanup
        ;;
    --interactive|-i)
        check_root
        interactive_cleanup
        ;;
    --dry-run|-d)
        dry_run
        ;;
    --version|-v)
        show_version
        ;;
    --help|-h)
        show_help
        ;;
    *)
        check_root
        interactive_cleanup
        ;;
esac 