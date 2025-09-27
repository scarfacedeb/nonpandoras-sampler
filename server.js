// server.js
const express = require('express');
const multer = require('multer');
const cors = require('cors');
const nodemailer = require('nodemailer');
const TelegramBot = require('node-telegram-bot-api');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');
const { v4: uuidv4 } = require('uuid');

// Загружаем переменные окружения из .env файла
dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

// Создаем папку для хранения временных файлов, если она не существует
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Настройка хранилища для multer
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadsDir);
  },
  filename: function (req, file, cb) {
    const extFromOriginal = path.extname(file.originalname || '');
    let ext = extFromOriginal && extFromOriginal.length > 0 ? extFromOriginal : null;
    if (!ext) {
      // Infer by mimetype
      if (file.mimetype === 'audio/mpeg') ext = '.mp3';
      else if (file.mimetype === 'audio/ogg') ext = '.ogg';
      else if (file.mimetype === 'audio/webm') ext = '.webm';
      else ext = '.webm';
    }
    const uniqueFilename = `${uuidv4()}${ext}`;
    cb(null, uniqueFilename);
  }
});

const upload = multer({ storage: storage });

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Служебные маршруты
app.use(express.static('public'));
app.use('/samples', express.static('samples'));

// Отдельный маршрут для страницы egg
app.get('/egg', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'egg.html'));
});

// Настройка Telegram бота
let telegramBot;
if (process.env.TELEGRAM_BOT_TOKEN) {
  telegramBot = new TelegramBot(process.env.TELEGRAM_BOT_TOKEN, { polling: false });
} else {
  console.warn('TELEGRAM_BOT_TOKEN не найден в файле .env. Функция отправки в Telegram не будет работать.');
}

// Настройка транспорта для отправки email
let emailTransporter;
try {
  if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
    emailTransporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
      }
    });
    console.log('Gmail транспорт успешно настроен');
  } else {
    console.warn('Настройки EMAIL не найдены в файле .env. Функция отправки Email не будет работать.');
    console.warn('Необходимо указать EMAIL_USER и EMAIL_PASS в .env файле');
  }
} catch (error) {
  console.error('Ошибка при настройке транспорта email:', error);
}

// Маршрут для отправки записанного аудио
app.post('/api/send-recording', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'Файл не загружен' });
    }

    const method = req.body.method;
    const email = req.body.email;
    const filePath = req.file.path;

    // Проверяем существование файла
    if (!fs.existsSync(filePath)) {
      return res.status(500).json({ success: false, error: 'Файл не найден на сервере' });
    }

    let result = { success: false, error: 'Неизвестный метод отправки' };

    if (method === 'email' && email && emailTransporter) {
      // Отправка по email
      result = await sendEmail(email, filePath, req.file.originalname, req.file.mimetype);
    } else if ((method === 'telegram' || method === 'telegram_voice') && telegramBot) {
      // Группа/канал для отправки: берем из запроса или из переменных окружения
      const chatId = req.body.chatId || process.env.TELEGRAM_GROUP_ID || process.env.TELEGRAM_DEFAULT_CHAT_ID || '-1003175867730';
      const caption = (req.body.message ? String(req.body.message).slice(0, 1024) : undefined);

      if (!chatId) {
        return res.status(400).json({ success: false, error: 'Не указан chatId и не настроен TELEGRAM_GROUP_ID' });
      }

      if (method === 'telegram_voice') {
        result = await sendTelegramVoice(chatId, filePath, caption);
      } else {
        result = await sendTelegram(chatId, filePath, caption);
      }
    }

    // Удаляем временный файл после отправки
    try {
      fs.unlinkSync(filePath);
    } catch (unlinkError) {
      console.error('Ошибка при удалении временного файла:', unlinkError);
    }

    return res.json(result);
  } catch (error) {
    console.error('Ошибка при обработке запроса:', error);
    return res.status(500).json({ success: false, error: 'Внутренняя ошибка сервера' });
  }
});

// Функция отправки на email
async function sendEmail(email, filePath, originalName, mimeType) {
  if (!emailTransporter) {
    return { success: false, error: 'Транспорт email не настроен' };
  }

  try {
    const ext = path.extname(filePath) || (mimeType === 'audio/mpeg' ? '.mp3' : '.webm');
    const attachName = originalName && originalName.trim().length > 0 ? originalName : `recording${ext}`;
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: 'Ваша запись из онлайн-сэмплера',
      text: 'Прикрепляем вашу запись из онлайн-сэмплера',
      attachments: [
        {
          filename: attachName,
          path: filePath,
          contentType: mimeType || undefined
        }
      ]
    };

    const info = await emailTransporter.sendMail(mailOptions);
    console.log('Email отправлен:', info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('Ошибка при отправке email:', error);
    return { success: false, error: error.message };
  }
}

// Функция отправки в Telegram
async function sendTelegram(chatId, filePath, caption) {
  if (!telegramBot) {
    return { success: false, error: 'Telegram бот не настроен' };
  }

  try {
    const response = await telegramBot.sendAudio(chatId, fs.createReadStream(filePath), {
      caption: caption || 'Ваша запись из онлайн-сэмплера'
    });
    console.log('Отправлено в Telegram, message_id:', response.message_id);
    return { success: true, messageId: response.message_id };
  } catch (error) {
    console.error('Ошибка при отправке в Telegram:', error);
    return { success: false, error: error.message };
  }
}

// Отправка голосового сообщения (OGG/Opus)
async function sendTelegramVoice(chatId, filePath, caption) {
  if (!telegramBot) {
    return { success: false, error: 'Telegram бот не настроен' };
  }

  try {
    const response = await telegramBot.sendVoice(chatId, fs.createReadStream(filePath), {
      caption: caption || 'Голосовое сообщение из онлайн-сэмплера'
    });
    console.log('Voice отправлено в Telegram, message_id:', response.message_id);
    return { success: true, messageId: response.message_id };
  } catch (error) {
    console.error('Ошибка при отправке voice в Telegram:', error);
    return { success: false, error: error.message };
  }
}

// Маршрут для проверки Telegram username
app.post('/api/verify-telegram', async (req, res) => {
  const username = req.body.username;
  
  if (!telegramBot) {
    return res.json({ success: false, error: 'Telegram бот не настроен' });
  }
  
  if (!username) {
    return res.json({ success: false, error: 'Не указан username' });
  }
  
  try {
    // Этот маршрут просто подтверждает, что бот работает.
    // Фактическая проверка username будет происходить в момент отправки
    return res.json({ success: true, verified: true });
  } catch (error) {
    console.error('Ошибка при проверке Telegram username:', error);
    return res.json({ success: false, error: error.message });
  }
});

// Запускаем сервер
app.listen(port, () => {
  console.log(`Сервер запущен на порту ${port}`);
  console.log(`Откройте http://localhost:${port} в браузере`);
});
