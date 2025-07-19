#!/bin/bash

# 🧹 УНИВЕРСАЛЬНЫЙ скрипт очистки Ubuntu/Debian
# Автор: AI Assistant
# Версия: 2.0-UNIVERSAL
# Описание: Автоматически определяет тип системы и предлагает подходящие опции

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
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Конфигурация
readonly SCRIPT_VERSION="2.0-UNIVERSAL"
readonly SCRIPT_NAME="Ubuntu Cleanup Universal"

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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Функция для отображения заголовка
show_header() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🧹 Ubuntu Cleanup Universal v$SCRIPT_VERSION                    ║"
    echo "║                                                                              ║"
    echo "║  Автоматическое определение типа системы и подходящих опций очистки         ║"
    echo "║  Поддерживаемые системы: Ubuntu 18.04+, Debian 9+                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Функция для получения информации о системе
get_system_info() {
    local os_name=""
    local os_version=""
    local system_type=""
    
    if [[ -f /etc/os-release ]]; then
        os_name=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        os_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    fi
    
    # Определение типа системы
    if [[ "$os_name" == "ubuntu" ]]; then
        if [[ "$os_version" == "18.04" || "$os_version" == "20.04" || "$os_version" == "22.04" ]]; then
            system_type="LTS"
        else
            system_type="REGULAR"
        fi
    elif [[ "$os_name" == "debian" ]]; then
        if [[ "$os_version" == "11" || "$os_version" == "12" ]]; then
            system_type="STABLE"
        else
            system_type="REGULAR"
        fi
    else
        system_type="UNKNOWN"
    fi
    
    echo "$os_name|$os_version|$system_type"
}

# Функция для определения типа сервера
detect_server_type() {
    local server_type="PERSONAL"
    
    # Проверка на продакшн сервер
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet postgresql 2>/dev/null; then
        server_type="PRODUCTION"
    elif systemctl is-active --quiet nginx 2>/dev/null || systemctl is-active --quiet apache2 2>/dev/null; then
        server_type="WEB_SERVER"
    elif systemctl is-active --quiet docker 2>/dev/null; then
        server_type="CONTAINER_SERVER"
    elif [[ -d "/var/lib/mysql" || -d "/var/lib/postgresql" ]]; then
        server_type="DATABASE_SERVER"
    fi
    
    echo "$server_type"
}

# Функция для получения свободного места
get_free_space_percent() {
    df / | awk 'NR==2 {print $5}' | sed 's/%//'
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

# Функция для отображения информации о системе
show_system_info() {
    local system_info=$(get_system_info)
    local os_name=$(echo "$system_info" | cut -d'|' -f1)
    local os_version=$(echo "$system_info" | cut -d'|' -f2)
    local system_type=$(echo "$system_info" | cut -d'|' -f3)
    local server_type=$(detect_server_type)
    local free_space=$(get_free_space_percent)
    
    echo -e "${CYAN}=== ИНФОРМАЦИЯ О СИСТЕМЕ ===${NC}"
    echo "Операционная система: $os_name $os_version ($system_type)"
    echo "Тип сервера: $server_type"
    echo "Свободное место на диске: $free_space%"
    echo ""
    
    # Рекомендации
    echo -e "${YELLOW}=== РЕКОМЕНДАЦИИ ===${NC}"
    if [[ "$server_type" == "PRODUCTION" || "$server_type" == "DATABASE_SERVER" ]]; then
        echo "🔴 РЕКОМЕНДУЕТСЯ: Использовать безопасный скрипт (cleanup_ubuntu_safe.sh)"
        echo "   Причина: Критически важные сервисы обнаружены"
    elif [[ "$free_space" -lt 20 ]]; then
        echo "🟡 РЕКОМЕНДУЕТСЯ: Выполнить полную очистку"
        echo "   Причина: Мало свободного места ($free_space%)"
    else
        echo "🟢 РЕКОМЕНДУЕТСЯ: Использовать стандартный скрипт (cleanup_ubuntu.sh)"
        echo "   Причина: Система в хорошем состоянии"
    fi
    echo ""
}

# Функция для быстрой очистки
quick_cleanup() {
    log "=== БЫСТРАЯ ОЧИСТКА ==="
    
    # Очистка APT кэша
    safe_execute "apt-get autoclean" "Автоочистка кэша APT"
    
    # Очистка временных файлов (только старые)
    safe_execute "find /tmp -type f -atime +7 -delete" "Очистка старых временных файлов"
    safe_execute "find /var/tmp -type f -atime +7 -delete" "Очистка старых файлов в /var/tmp"
    
    # Очистка логов (только очень старые)
    safe_execute "find /var/log -name '*.log.*' -type f -mtime +30 -delete" "Очистка старых логов"
    
    # Очистка корзины
    safe_execute "rm -rf /home/*/.local/share/Trash/*" "Очистка корзины пользователей"
    
    log "✓ Быстрая очистка завершена"
}

# Функция для полной очистки
full_cleanup() {
    log "=== ПОЛНАЯ ОЧИСТКА ==="
    
    # Очистка APT кэша
    safe_execute "apt-get clean" "Полная очистка кэша APT"
    safe_execute "apt-get autoclean" "Автоочистка кэша APT"
    
    # Очистка неиспользуемых пакетов
    safe_execute "apt-get autoremove -y" "Удаление неиспользуемых пакетов"
    
    # Очистка временных файлов
    safe_execute "rm -rf /tmp/*" "Очистка /tmp"
    safe_execute "rm -rf /var/tmp/*" "Очистка /var/tmp"
    
    # Очистка логов
    safe_execute "find /var/log -name '*.log.*' -type f -mtime +7 -delete" "Очистка старых логов"
    
    # Очистка корзины
    safe_execute "rm -rf /home/*/.local/share/Trash/*" "Очистка корзины"
    
    # Очистка кэша разработчиков
    safe_execute "pip cache purge 2>/dev/null || true" "Очистка кэша pip"
    safe_execute "npm cache clean --force 2>/dev/null || true" "Очистка кэша npm"
    
    log "✓ Полная очистка завершена"
}

# Функция для анализа системы
analyze_system() {
    log "=== АНАЛИЗ СИСТЕМЫ ==="
    
    echo "📊 Использование диска:"
    df -h /
    echo ""
    
    echo "📁 Самые большие директории:"
    du -h /var/log /var/cache /tmp /home 2>/dev/null | sort -hr | head -10
    echo ""
    
    echo "📦 Размер кэша APT:"
    du -sh /var/cache/apt/archives 2>/dev/null || echo "Кэш APT не найден"
    echo ""
    
    echo "🔍 Большие файлы (>100MB):"
    find / -type f -size +100M 2>/dev/null | head -10
    echo ""
}

# Функция для очистки WordPress audit logs
clean_wordpress_audit_logs() {
    log "=== ОЧИСТКА WORDPRESS AUDIT LOGS ==="
    
    if ! command -v mysql &> /dev/null; then
        warn "MySQL не установлен, пропускаем очистку WordPress audit logs"
        return 0
    fi
    
    local mysql_data_dir="/var/lib/mysql"
    if [[ ! -d "$mysql_data_dir" ]]; then
        warn "Директория MySQL данных не найдена: $mysql_data_dir"
        return 0
    fi
    
    echo -e "${YELLOW}Поиск файлов aiowps audit logs в базах данных...${NC}"
    
    # Поиск всех файлов aiowps audit logs (файлы, заканчивающиеся на aiowps_audit_log)
    local audit_logs=$(find "$mysql_data_dir" -name "*aiowps_audit_log*" -type f 2>/dev/null)
    
    if [[ -z "$audit_logs" ]]; then
        echo -e "${GREEN}Файлы aiowps audit logs не найдены${NC}"
        return 0
    fi
    
    local total_size=0
    local file_count=0
    
    echo -e "${YELLOW}Найдены файлы aiowps audit logs:${NC}"
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
    
    echo -e "${YELLOW}⚠️  ВНИМАНИЕ: Удаление этих файлов может повлиять на работу WordPress сайтов!${NC}"
    echo -e "${YELLOW}Эти файлы содержат логи безопасности плагина All In One WP Security.${NC}"
    echo ""
    
    read -p "Продолжить удаление найденных файлов aiowps audit logs? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Удаление aiowps audit logs пропущено${NC}"
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
        
        if rm -f "$file" 2>/dev/null; then
            local file_name=$(basename "$file")
            echo -e "${GREEN}✓ Удален: $db_name/$file_name ($(numfmt --to=iec $size))${NC}"
            ((removed_count++))
            removed_size=$((removed_size + size))
        else
            local file_name=$(basename "$file")
            echo -e "${RED}✗ Не удалось удалить: $db_name/$file_name${NC}"
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
    echo -e "${GREEN}Очистка aiowps audit logs завершена:${NC}"
    echo -e "${GREEN}  - Удалено файлов: $removed_count из $file_count${NC}"
    echo -e "${GREEN}  - Освобождено места: $(numfmt --to=iec $removed_size)${NC}"
    echo ""
}

# Функция для удаления папок веб-серверов
remove_web_server_dirs() {
    log "=== ПОЛНОЕ УДАЛЕНИЕ ПАПОК ВЕБ-СЕРВЕРОВ ==="
    
    echo -e "${YELLOW}⚠️  ВНИМАНИЕ: Эта операция полностью удалит папки логов Apache2 и Nginx${NC}"
    echo -e "${YELLOW}Это может повлиять на работу веб-серверов!${NC}"
    echo ""
    
    read -p "Продолжить удаление папок /var/log/apache2 и /var/log/nginx? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Удаление папок веб-серверов пропущено${NC}"
        return 0
    fi
    
    # Удаление папки Apache2
    if [[ -d "/var/log/apache2" ]]; then
        local apache_size=$(du -sb /var/log/apache2 2>/dev/null | cut -f1 || echo "0")
        echo -e "${YELLOW}Удаление папки /var/log/apache2 (размер: $(numfmt --to=iec $apache_size))...${NC}"
        
        if rm -rf /var/log/apache2 2>/dev/null; then
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
        
        if rm -rf /var/log/nginx 2>/dev/null; then
            echo -e "${GREEN}✓ Папка /var/log/nginx успешно удалена${NC}"
        else
            echo -e "${RED}✗ Не удалось удалить папку /var/log/nginx${NC}"
        fi
    else
        echo -e "${YELLOW}Папка /var/log/nginx не существует${NC}"
    fi
    
    echo ""
}

# Функция для отображения главного меню
show_main_menu() {
    local system_info=$(get_system_info)
    local os_name=$(echo "$system_info" | cut -d'|' -f1)
    local os_version=$(echo "$system_info" | cut -d'|' -f2)
    local server_type=$(detect_server_type)
    local free_space=$(get_free_space_percent)
    
    show_header
    show_system_info
    
    echo -e "${CYAN}=== ГЛАВНОЕ МЕНЮ ===${NC}"
    echo "1. 🔍 Анализ системы"
    echo "2. ⚡ Быстрая очистка (безопасная)"
    echo "3. 🧹 Полная очистка (агрессивная)"
    echo "4. 🛡️ Запустить безопасный скрипт"
    echo "5. 🚀 Запустить стандартный скрипт"
    echo "6. 📊 Показать статистику"
    echo "7. 🗄️ Очистка WordPress audit logs"
    echo "8. 🌐 Удаление папок веб-серверов"
    echo "9. ❓ Справка"
    echo "0. 🚪 Выход"
    echo ""
    
    read -p "Выберите опцию (0-9): " choice
    
    case $choice in
        1)
            analyze_system
            read -p "Нажмите Enter для продолжения..."
            show_main_menu
            ;;
        2)
            echo -e "${YELLOW}Выполняется быстрая очистка...${NC}"
            quick_cleanup
            read -p "Нажмите Enter для продолжения..."
            show_main_menu
            ;;
        3)
            echo -e "${RED}ВНИМАНИЕ: Полная очистка удалит больше файлов!${NC}"
            read -p "Продолжить? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                full_cleanup
            fi
            read -p "Нажмите Enter для продолжения..."
            show_main_menu
            ;;
        4)
            if [[ -f "./cleanup_ubuntu_safe.sh" ]]; then
                echo -e "${GREEN}Запуск безопасного скрипта...${NC}"
                ./cleanup_ubuntu_safe.sh
            else
                error "Файл cleanup_ubuntu_safe.sh не найден"
                echo "Скачайте его: wget https://raw.githubusercontent.com/Traffic-Connect/Ubuntu-Cleanup-Suite/main/cleanup_ubuntu_safe.sh"
            fi
            read -p "Нажмите Enter для продолжения..."
            show_main_menu
            ;;
        5)
            if [[ -f "./cleanup_ubuntu.sh" ]]; then
                echo -e "${GREEN}Запуск стандартного скрипта...${NC}"
                ./cleanup_ubuntu.sh
            else
                error "Файл cleanup_ubuntu.sh не найден"
                echo "Скачайте его: wget https://raw.githubusercontent.com/Traffic-Connect/Ubuntu-Cleanup-Suite/main/cleanup_ubuntu.sh"
            fi
            read -p "Нажмите Enter для продолжения..."
            show_main_menu
            ;;
        6)
            echo -e "${CYAN}=== СТАТИСТИКА ===${NC}"
            echo "Операций выполнено: $operations_count"
            echo "Места освобождено: $(numfmt --to=iec $total_space_freed 2>/dev/null || echo "N/A")"
            echo "Критических операций пропущено: $critical_operations_skipped"
            read -p "Нажмите Enter для продолжения..."
            show_main_menu
            ;;
        7)
            clean_wordpress_audit_logs
            read -p "Нажмите Enter для продолжения..."
            show_main_menu
            ;;
        8)
            remove_web_server_dirs
            read -p "Нажмите Enter для продолжения..."
            show_main_menu
            ;;
        9)
            show_help
            read -p "Нажмите Enter для продолжения..."
            show_main_menu
            ;;
        0)
            echo -e "${GREEN}Спасибо за использование $SCRIPT_NAME!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
            sleep 2
            show_main_menu
            ;;
    esac
}

# Функция для отображения справки
show_help() {
    echo -e "${CYAN}=== СПРАВКА ===${NC}"
    echo ""
    echo "🧹 $SCRIPT_NAME v$SCRIPT_VERSION"
    echo ""
    echo "Этот скрипт автоматически определяет тип вашей системы и предлагает"
    echo "подходящие опции очистки."
    echo ""
    echo "📋 Опции меню:"
    echo "1. Анализ системы - показывает текущее состояние"
    echo "2. Быстрая очистка - безопасная очистка основных файлов"
    echo "3. Полная очистка - агрессивная очистка всех ненужных файлов"
    echo "4. Безопасный скрипт - запуск специализированного безопасного скрипта"
    echo "5. Стандартный скрипт - запуск стандартного скрипта очистки"
    echo "6. Статистика - показывает результаты очистки"
    echo "7. Очистка WordPress audit logs - удаление wp_aiowps_audit_log.ibd файлов"
    echo "8. Удаление папок веб-серверов - полное удаление /var/log/apache2 и /var/log/nginx"
    echo "9. Справка - эта информация"
    echo "0. Выход - завершение работы"
    echo ""
    echo "🔗 Документация:"
    echo "GitHub: https://github.com/Traffic-Connect/Ubuntu-Cleanup-Suite"
    echo "Issues: https://github.com/Traffic-Connect/Ubuntu-Cleanup-Suite/issues"
    echo ""
    echo "⚠️  ВНИМАНИЕ: Всегда создавайте резервные копии перед очисткой!"
}

# Функция для обработки аргументов командной строки
handle_arguments() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --version|-v)
            echo "$SCRIPT_NAME v$SCRIPT_VERSION"
            exit 0
            ;;
        --quick|-q)
            quick_cleanup
            exit 0
            ;;
        --full|-f)
            full_cleanup
            exit 0
            ;;
        --analyze|-a)
            analyze_system
            exit 0
            ;;
        --safe|-s)
            if [[ -f "./cleanup_ubuntu_safe.sh" ]]; then
                ./cleanup_ubuntu_safe.sh
            else
                error "Файл cleanup_ubuntu_safe.sh не найден"
                exit 1
            fi
            ;;
        --standard|-std)
            if [[ -f "./cleanup_ubuntu.sh" ]]; then
                ./cleanup_ubuntu.sh
            else
                error "Файл cleanup_ubuntu.sh не найден"
                exit 1
            fi
            ;;
        "")
            # Без аргументов - показать интерактивное меню
            ;;
        *)
            error "Неизвестный аргумент: $1"
            echo "Использование: $0 [опции]"
            echo "Опции: --help, --version, --quick, --full, --analyze, --safe, --standard"
            exit 1
            ;;
    esac
}

# Главная функция
main() {
    # Обработка аргументов командной строки
    handle_arguments "$@"
    
    # Проверки
    check_root
    check_system
    
    # Показать интерактивное меню
    show_main_menu
}

# Запуск главной функции
main "$@" 