@echo off
setlocal

title Онлайн-сэмплер: Запуск

echo ====== Онлайн-сэмплер: Запуск ======
echo.

:: Проверка наличия Node.js
where node >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ОШИБКА] Node.js не установлен! Пожалуйста, установите Node.js и npm:
    echo https://nodejs.org/en/download/
    echo.
    echo Нажмите любую клавишу для выхода...
    pause >nul
    exit /b 1
)

:: Проверка версии Node.js (нам нужна версия 14+)
for /f "tokens=1,2,3 delims=v." %%a in ('node -v') do (
    set NODE_VERSION=%%b
)
if %NODE_VERSION% LSS 14 (
    echo [ОШИБКА] Требуется Node.js версии 14 или выше.
    echo Пожалуйста, обновите Node.js: https://nodejs.org/en/download/
    echo.
    echo Нажмите любую клавишу для выхода...
    pause >nul
    exit /b 1
)

:: Проверка наличия файла .env
if not exist .env (
    echo [ИНФО] Файл .env не найден. Создаем шаблон...
    (
        echo # Настройки сервера
        echo PORT=3000
        echo.
        echo # Настройки Telegram бота
        echo # Получите токен от @BotFather в Telegram
        echo TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
        echo # ID чата по умолчанию, если пользователь не указал свой
        echo TELEGRAM_DEFAULT_CHAT_ID=
        echo.
        echo # Настройки email (Yandex)
        echo EMAIL_SERVICE=Yandex
        echo EMAIL_USER=your_yandex_email@yandex.ru
        echo EMAIL_PASS=your_app_password_here
    ) > .env
    echo [УСПЕХ] Файл .env создан. Пожалуйста, отредактируйте его, чтобы добавить свои настройки.
    echo.
)

:: Проверка структуры проекта
if not exist public (
    echo [ИНФО] Создаем папку public...
    mkdir public
)

:: Копируем index.html в public, если он находится в корне
if exist index.html (
    if not exist public\index.html (
        echo [ИНФО] Перемещаем index.html в папку public...
        copy index.html public\index.html
    )
)

:: Проверка наличия папки uploads
if not exist uploads (
    echo [ИНФО] Создаем папку uploads...
    mkdir uploads
)

:: Установка зависимостей, если нужно
if not exist node_modules (
    echo [ИНФО] Устанавливаем зависимости...
    call npm install
    
    if %ERRORLEVEL% neq 0 (
        echo [ОШИБКА] Ошибка при установке зависимостей. Пожалуйста, проверьте подключение к интернету и повторите попытку.
        echo.
        echo Нажмите любую клавишу для выхода...
        pause >nul
        exit /b 1
    )
    
    echo [УСПЕХ] Зависимости успешно установлены.
    echo.
)

:: Запуск сервера
echo [ИНФО] Запускаем сервер...
echo Для остановки сервера нажмите Ctrl+C
echo.
node server.js

echo.
echo Нажмите любую клавишу для выхода...
pause >nul
exit /b 0
