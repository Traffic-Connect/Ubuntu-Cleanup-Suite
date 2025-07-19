#!/bin/bash

# Скрипт-установщик для Ubuntu Cleanup Suite
# Автор: AI Assistant
# Версия: 1.0

# Цвета для вывода
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Базовый URL репозитория
readonly BASE_URL="https://raw.githubusercontent.com/Traffic-Connect/Ubuntu-Cleanup-Suite/main"

# Название папки проекта
readonly PROJECT_DIR="ubuntu-cleanup-suite"

# Список файлов для скачивания
readonly FILES=(
    "ubuntu_cleanup.sh"
    "cleanup_ubuntu.sh"
    "cleanup_ubuntu_safe.sh"
    "README.md"
)

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

# Проверка наличия wget
check_wget() {
    if ! command -v wget &> /dev/null; then
        error "wget не установлен. Установите его командой:"
        echo "sudo apt-get update && sudo apt-get install wget"
        exit 1
    fi
}

# Создание папки проекта
create_project_directory() {
    log "=== СОЗДАНИЕ ПАПКИ ПРОЕКТА ==="
    echo ""
    
    if [[ -d "$PROJECT_DIR" ]]; then
        warn "Папка $PROJECT_DIR уже существует"
        read -p "Перезаписать существующую папку? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            error "Установка отменена"
            exit 1
        fi
        rm -rf "$PROJECT_DIR"
        log "Существующая папка удалена"
    fi
    
    if mkdir -p "$PROJECT_DIR"; then
        log "✓ Папка $PROJECT_DIR создана"
        cd "$PROJECT_DIR" || {
            error "Не удалось перейти в папку $PROJECT_DIR"
            exit 1
        }
    else
        error "✗ Не удалось создать папку $PROJECT_DIR"
        exit 1
    fi
}

# Скачивание файла
download_file() {
    local file="$1"
    local url="$BASE_URL/$file"
    
    log "Скачивание: $file"
    if wget -q --show-progress "$url" -O "$file"; then
        log "✓ $file успешно скачан"
        return 0
    else
        error "✗ Не удалось скачать $file"
        return 1
    fi
}

# Скачивание всех файлов
download_all_files() {
    log "=== СКАЧИВАНИЕ ФАЙЛОВ UBUNTU CLEANUP SUITE ==="
    echo ""
    
    local success_count=0
    local total_count=${#FILES[@]}
    
    for file in "${FILES[@]}"; do
        if download_file "$file"; then
            ((success_count++))
        fi
    done
    
    echo ""
    log "Скачано файлов: $success_count из $total_count"
    
    if [[ $success_count -eq $total_count ]]; then
        log "✓ Все файлы успешно скачаны!"
    else
        warn "Некоторые файлы не удалось скачать"
    fi
}

# Сделать скрипты исполняемыми
make_executable() {
    log "=== НАСТРОЙКА ПРАВ ДОСТУПА ==="
    echo ""
    
    local script_files=("ubuntu_cleanup.sh" "cleanup_ubuntu.sh" "cleanup_ubuntu_safe.sh")
    
    for script in "${script_files[@]}"; do
        if [[ -f "$script" ]]; then
            if chmod +x "$script"; then
                log "✓ $script сделан исполняемым"
            else
                error "✗ Не удалось сделать $script исполняемым"
            fi
        else
            warn "Файл $script не найден"
        fi
    done
}

# Показать инструкции по использованию
show_usage_instructions() {
    echo ""
    log "=== ИНСТРУКЦИИ ПО ИСПОЛЬЗОВАНИЮ ==="
    echo ""
    echo -e "${BLUE}📁 Папка проекта:${NC}"
    echo "Все файлы скачаны в папку: $PROJECT_DIR"
    echo ""
    echo -e "${BLUE}🚀 Быстрый старт (рекомендуется):${NC}"
    echo "cd $PROJECT_DIR"
    echo "sudo ./ubuntu_cleanup.sh"
    echo ""
    echo -e "${BLUE}📋 Доступные скрипты:${NC}"
    echo "• ubuntu_cleanup.sh - Универсальный скрипт (рекомендуется)"
    echo "• cleanup_ubuntu.sh - Стандартный скрипт"
    echo "• cleanup_ubuntu_safe.sh - Безопасный скрипт для серверов"
    echo ""
    echo -e "${BLUE}📖 Документация:${NC}"
    echo "• README.md - Основная документация и инструкции"
    echo ""
    echo -e "${BLUE}🔧 Примеры использования:${NC}"
    echo "cd $PROJECT_DIR"
    echo "sudo ./ubuntu_cleanup.sh --help"
    echo "sudo ./cleanup_ubuntu_safe.sh --interactive"
    echo "sudo ./cleanup_ubuntu.sh --analyze"
    echo ""
    echo -e "${YELLOW}⚠️  ВАЖНО: Все скрипты должны запускаться с правами администратора (sudo)${NC}"
    echo ""
}

# Основная функция
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                UBUNTU CLEANUP SUITE INSTALLER                ║"
    echo "║                    Установщик системы очистки                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Проверка wget
    check_wget
    
    # Создание папки проекта
    create_project_directory
    
    # Скачивание файлов
    download_all_files
    
    # Настройка прав доступа
    make_executable
    
    # Показать инструкции
    show_usage_instructions
    
    log "Установка завершена! Все файлы находятся в папке: $PROJECT_DIR"
}

# Запуск основной функции
main "$@" 