#!/bin/bash

# Определяем цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}====== Онлайн-сэмплер: Запуск ======${NC}"

# Проверка наличия Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js не установлен! Пожалуйста, установите Node.js и npm:${NC}"
    echo -e "${BLUE}https://nodejs.org/en/download/${NC}"
    exit 1
fi

# Проверка версии Node.js (нам нужна версия 14+)
NODE_VERSION=$(node -v | cut -d 'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 14 ]; then
    echo -e "${RED}Требуется Node.js версии 14 или выше. У вас установлена версия $(node -v)${NC}"
    echo -e "${BLUE}Пожалуйста, обновите Node.js: https://nodejs.org/en/download/${NC}"
    exit 1
fi

# Проверка наличия файла .env
if [ ! -f .env ]; then
    echo -e "${YELLOW}Файл .env не найден. Создаем шаблон...${NC}"
    cat > .env << EOL
# Настройки сервера
PORT=3000

# Настройки Telegram бота
# Получите токен от @BotFather в Telegram
TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
# ID чата по умолчанию, если пользователь не указал свой
TELEGRAM_DEFAULT_CHAT_ID=

# Настройки email (Yandex)
EMAIL_SERVICE=Yandex
EMAIL_USER=your_yandex_email@yandex.ru
EMAIL_PASS=your_app_password_here
EOL
    echo -e "${GREEN}Файл .env создан. Пожалуйста, отредактируйте его, чтобы добавить свои настройки.${NC}"
fi

# Проверка структуры проекта
if [ ! -d "public" ]; then
    echo -e "${YELLOW}Создаем папку public...${NC}"
    mkdir -p public
fi

# Копируем index.html в public, если он находится в корне
if [ -f "index.html" ] && [ ! -f "public/index.html" ]; then
    echo -e "${YELLOW}Перемещаем index.html в папку public...${NC}"
    cp index.html public/index.html
fi

# Проверка наличия папки uploads
if [ ! -d "uploads" ]; then
    echo -e "${YELLOW}Создаем папку uploads...${NC}"
    mkdir -p uploads
fi

# Создаем структуру папок для сэмплов
if [ ! -d "samples" ]; then
    echo -e "${YELLOW}Создаем папку для сэмплов...${NC}"
    mkdir -p samples
    echo -e "${GREEN}Папка для сэмплов создана. Не забудьте добавить MP3 файлы 1.mp3, 2.mp3, 3.mp3, 4.mp3, 5.mp3 в эту папку.${NC}"
fi

# Установка зависимостей, если нужно
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Устанавливаем зависимости...${NC}"
    npm install
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при установке зависимостей. Пожалуйста, проверьте подключение к интернету и повторите попытку.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Зависимости успешно установлены.${NC}"
fi

# Функция для наблюдения за файлом index.html и его синхронизации
watch_index_html() {
    echo -e "${BLUE}Запущено отслеживание изменений в index.html...${NC}"
    
    # Получаем начальную временную метку файла
    if [ -f "index.html" ]; then
        LAST_MODIFIED=$(stat -c %Y "index.html" 2>/dev/null || stat -f %m "index.html" 2>/dev/null)
    else
        LAST_MODIFIED=0
    fi
    
    while true; do
        # Если файл существует, проверяем его временную метку
        if [ -f "index.html" ]; then
            CURRENT_MODIFIED=$(stat -c %Y "index.html" 2>/dev/null || stat -f %m "index.html" 2>/dev/null)
            
            # Если файл изменился, копируем его
            if [ "$CURRENT_MODIFIED" != "$LAST_MODIFIED" ]; then
                echo -e "${GREEN}Обнаружены изменения в index.html! Обновляем файл в папке public...${NC}"
                cp "index.html" "public/index.html"
                LAST_MODIFIED=$CURRENT_MODIFIED
            fi
        fi
        
        # Ждем 1 секунду перед следующей проверкой
        sleep 1
    done
}

# Запускаем наблюдение за файлом index.html в фоновом режиме
watch_index_html &
WATCH_PID=$!

# Функция для корректного завершения скрипта и всех порожденных процессов
cleanup() {
    echo -e "\n${YELLOW}Остановка сервера и всех процессов...${NC}"
    kill $WATCH_PID 2>/dev/null
    exit 0
}

# Устанавливаем обработчик для корректного завершения по Ctrl+C
trap cleanup SIGINT SIGTERM

# Запуск сервера
echo -e "${GREEN}Запускаем сервер...${NC}"
echo -e "${BLUE}Для остановки сервера нажмите Ctrl+C${NC}"
node server.js

# Останавливаем процесс наблюдения при выходе
cleanup
