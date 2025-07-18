# 🤝 Руководство для контрибьюторов

Спасибо за интерес к проекту скриптов очистки Ubuntu! Мы приветствуем вклад от сообщества.

## 📋 Как внести вклад

### 🐛 Сообщить об ошибке
1. Проверьте, не была ли ошибка уже зарегистрирована в [Issues](https://github.com/Traffic-Connect/Ubuntu-Cleanup-Suite/issues)
2. Создайте новое issue с подробным описанием проблемы
3. Включите информацию о системе, версии скрипта и шаги воспроизведения

### 💡 Предложить улучшение
1. Создайте issue с описанием предлагаемого улучшения
2. Обсудите идею с сообществом
3. Дождитесь одобрения перед началом работы

### 🔧 Внести код
1. Fork репозиторий
2. Создайте feature branch: `git checkout -b feature/amazing-feature`
3. Внесите изменения
4. Добавьте тесты (если применимо)
5. Commit изменения: `git commit -m 'Add amazing feature'`
6. Push в branch: `git push origin feature/amazing-feature`
7. Откройте Pull Request

## 📝 Стандарты кода

### Bash скрипты
- Используйте Bash 4.0+ совместимый синтаксис
- Следуйте [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Добавляйте комментарии к сложным функциям
- Используйте `set -euo pipefail` для безопасности

### Документация
- Пишите на русском языке
- Используйте Markdown форматирование
- Добавляйте эмодзи для лучшей читаемости
- Включайте примеры использования

### Git коммиты
- Используйте понятные сообщения коммитов
- Начинайте с глагола в повелительном наклонении
- Ограничивайте длину строки 72 символами
- Используйте префиксы: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`

## 🧪 Тестирование

### Локальное тестирование
```bash
# Тестирование на Ubuntu/Debian
sudo ./cleanup_ubuntu.sh --dry-run
sudo ./cleanup_ubuntu_safe.sh --dry-run

# Проверка синтаксиса
bash -n cleanup_ubuntu.sh
bash -n cleanup_ubuntu_safe.sh

# Проверка с shellcheck
shellcheck cleanup_ubuntu.sh
shellcheck cleanup_ubuntu_safe.sh
```

### Тестовые среды
- Ubuntu 18.04 LTS
- Ubuntu 20.04 LTS
- Ubuntu 22.04 LTS
- Debian 11
- Debian 12

## 📋 Процесс Pull Request

### Перед отправкой PR
1. Убедитесь, что код соответствует стандартам
2. Добавьте тесты для новых функций
3. Обновите документацию
4. Проверьте, что все тесты проходят

### Шаблон Pull Request
```markdown
## Описание
Краткое описание изменений

## Тип изменений
- [ ] Исправление ошибки
- [ ] Новая функция
- [ ] Улучшение документации
- [ ] Рефакторинг кода
- [ ] Тесты

## Тестирование
- [ ] Протестировано на Ubuntu 20.04
- [ ] Протестировано на Debian 11
- [ ] Все тесты проходят
- [ ] Документация обновлена

## Чек-лист
- [ ] Код соответствует стандартам
- [ ] Добавлены комментарии к сложным функциям
- [ ] Обновлена документация
- [ ] Добавлены тесты (если применимо)
- [ ] Коммиты имеют понятные сообщения
```

## 🏷️ Система меток

### Issues
- `bug` - Ошибки и проблемы
- `enhancement` - Предложения улучшений
- `documentation` - Улучшения документации
- `good first issue` - Подходящие для новичков
- `help wanted` - Требуется помощь
- `question` - Вопросы и обсуждения

### Pull Requests
- `WIP` - Работа в процессе
- `ready for review` - Готово к проверке
- `breaking change` - Критические изменения
- `security` - Изменения безопасности

## 📞 Связь

### Каналы связи
- **Issues** - для ошибок и предложений
- **Discussions** - для общих вопросов
- **Email** - для приватных вопросов

### Правила поведения
- Будьте уважительны к другим участникам
- Используйте конструктивную критику
- Помогайте новичкам
- Следуйте [Code of Conduct](CODE_OF_CONDUCT.md)

## 🏆 Признание вклада

### Hall of Fame
Контрибьюторы будут добавлены в:
- README.md файл
- Специальную страницу контрибьюторов
- Release notes

### Значки
- 🥇 Золотой - за значительный вклад
- 🥈 Серебряный - за регулярные улучшения
- 🥉 Бронзовый - за первые вклады

## 📚 Полезные ресурсы

### Документация
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
- [Markdown Guide](https://www.markdownguide.org/)
- [Git Handbook](https://guides.github.com/introduction/git-handbook/)

### Инструменты
- [ShellCheck](https://www.shellcheck.net/) - статический анализ Bash
- [Bash Debug](https://bashdb.sourceforge.net/) - отладчик Bash
- [GitHub Desktop](https://desktop.github.com/) - GUI для Git

## 🚀 Быстрый старт

### Первый вклад
1. Найдите issue с меткой `good first issue`
2. Оставьте комментарий, что хотите работать над ним
3. Следуйте инструкциям выше
4. Не стесняйтесь задавать вопросы!

### Получение помощи
- Используйте Discussions для вопросов
- Обратитесь к существующим контрибьюторам
- Изучите существующий код и документацию

---

**Спасибо за ваш вклад в проект!** 🎉

---

**Версия:** 1.0  
**Последнее обновление:** 2024  
**Статус:** Активно развивается 🚀 