require('dotenv').config();
const express    = require('express');
const http       = require('http');
const path       = require('path');
const { Server } = require('socket.io');
const cors       = require('cors');
const axios      = require('axios');

const agoraTokenRouter = require('./routes/agora');
const roomRouter       = require('./routes/rooms');
const roomManager      = require('./managers/RoomManager');

const JAVA_API = process.env.JAVA_API_URL || 'http://localhost:8085';

// ─────────────────────────────────────────
//  App Setup
// ─────────────────────────────────────────
const app    = express();
const server = http.createServer(app);
const io     = new Server(server, {
    cors: {
        origin : (process.env.ALLOWED_ORIGINS || '*').split(','),
        methods: ['GET', 'POST'],
    },
});

app.use(cors({ origin: (process.env.ALLOWED_ORIGINS || '*').split(',') }));
app.use(express.json());

// ─────────────────────────────────────────
//  REST Routes
// ─────────────────────────────────────────
app.use('/api/agora', agoraTokenRouter);   // Tạo Agora Token
app.use('/api/rooms', roomRouter);          // Danh sách phòng

app.get('/health', (_req, res) => {
    res.json({
        service  : 'LUCY Real-time Service',
        status   : 'OK',
        rooms    : roomManager.getRoomCount(),
        users    : roomManager.getTotalUsers(),
        timestamp: new Date().toISOString(),
    });
});

// Proxy sang Java API (tránh CORS khi mở demo từ trình duyệt)
app.get('/proxy/java-stats', async (_req, res) => {
    try {
        const { data } = await axios.get(`${JAVA_API}/api/stats`, { timeout: 4000 });
        res.json(data);
    } catch (e) {
        res.status(502).json({ error: 'Java API offline', detail: e.message });
    }
});

// Serve trang demo.html trực tiếp tại http://localhost:3000/demo
app.get('/demo', (_req, res) => {
    res.sendFile(path.join(__dirname, '..', 'demo.html'));
});

// ─────────────────────────────────────────
//  Socket.io – Real-time events
// ─────────────────────────────────────────
require('./socket/roomSocket')(io, roomManager);

// ─────────────────────────────────────────
//  Start
// ─────────────────────────────────────────
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log('');
    console.log('╔══════════════════════════════════════════════╗');
    console.log('║   LUCY Real-time Service đã khởi động!       ║');
    console.log(`║   Port   : ${PORT}                               ║`);
    console.log(`║   Health : http://localhost:${PORT}/health        ║`);
    console.log('╚══════════════════════════════════════════════╝');
    console.log('');
});

module.exports = { app, server, io };
