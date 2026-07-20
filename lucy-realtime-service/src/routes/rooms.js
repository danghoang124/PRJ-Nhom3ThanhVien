const express     = require('express');
const router      = express.Router();
const axios       = require('axios');
const roomManager = require('../managers/RoomManager');
const { authenticateToken } = require('../middleware/auth');

const JAVA_API = process.env.JAVA_API_URL || 'http://localhost:8085';

/**
 * GET /api/rooms
 * Query: ?lang=en&status=active
 * → Danh sách phòng đang hoạt động
 */
router.get('/', (req, res) => {
    const { lang, status } = req.query;
    const rooms = roomManager.listRooms({ languageCode: lang, status });
    res.json({ total: rooms.length, rooms });
});

/**
 * POST /api/rooms
 * Body: { levelId, languageCode, levelNumber }
 * → Tạo phòng mới, gọi Java API để lấy thông tin Level
 * Requires: JWT Token (Authorization: Bearer <token>)
 */
router.post('/', authenticateToken, async (req, res) => {
    const { levelId } = req.body;
    const languageCode = req.body.languageCode || 'en';
    const levelNumber = req.body.levelNumber || 1;

    if (!levelId) {
        return res.status(400).json({ error: 'levelId là bắt buộc' });
    }

    try {
        // Gọi Java API lấy nội dung Level
        const { data: levelData } = await axios.get(`${JAVA_API}/api/levels/${levelId}`, {
            timeout: 5000
        });

        const creatorEmail = req.user['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] || req.user.email || '';

        const room = roomManager.createRoom({
            levelId,
            languageCode,
            levelNumber,
            levelTitle    : levelData.title,
            totalSubLevels: levelData.subLevels ? levelData.subLevels.length : 6,
            subLevels     : levelData.subLevels || [],
            creatorEmail,
        });

        return res.status(201).json({
            message     : 'Tạo phòng thành công',
            room,
            levelContent: levelData,
        });

    } catch (err) {
        console.error('Lỗi gọi Java API:', err.message);
        const creatorEmail = req.user['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] || req.user.email || '';
        // Nếu Java API down, vẫn tạo phòng được (graceful fallback)
        const room = roomManager.createRoom({ 
            levelId, 
            languageCode, 
            levelNumber,
            creatorEmail
        });
        return res.status(201).json({
            message : 'Tạo phòng thành công (không lấy được level data từ Java API)',
            room,
            warning : err.message,
        });
    }
});

/**
 * GET /api/rooms/:roomId
 * → Chi tiết 1 phòng
 */
router.get('/:roomId', (req, res) => {
    const room = roomManager.getRoom(req.params.roomId);
    if (!room) {
        return res.status(404).json({ error: 'Không tìm thấy phòng' });
    }
    res.json(room);
});

/**
 * GET /api/rooms/:roomId/level-content
 * → Lấy nội dung Level từ Java API (để Mobile hiển thị câu hỏi)
 */
router.get('/:roomId/level-content', async (req, res) => {
    const room = roomManager.getRoom(req.params.roomId);
    if (!room) {
        return res.status(404).json({ error: 'Không tìm thấy phòng' });
    }

    try {
        const { data } = await axios.get(`${JAVA_API}/api/levels/${room.levelId}`, {
            timeout: 5000
        });
        res.json(data);
    } catch (err) {
        res.status(502).json({ error: 'Không lấy được nội dung từ Java service', detail: err.message });
    }
});

/**
 * DELETE /api/rooms/:roomId
 * → Kết thúc phòng (chỉ dùng khi test)
 */
router.delete('/:roomId', authenticateToken, (req, res) => {
    const room = roomManager.getRoom(req.params.roomId);
    if (!room) return res.status(404).json({ error: 'Không tìm thấy phòng' });

    const userEmail = req.user['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] || req.user.email;
    const userRole = req.user['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] || req.user.role;

    const isAdmin = userRole === 'admin' || userRole === 'mentor';
    const isCreator = room.creatorEmail === userEmail;

    if (!isAdmin && !isCreator) {
        return res.status(403).json({ error: 'Bạn không có quyền xóa phòng này. Chỉ Admin hoặc người tạo phòng mới được xóa.' });
    }

    roomManager.rooms.delete(req.params.roomId);
    res.json({ message: `Đã xóa phòng ${req.params.roomId}` });
});

module.exports = router;
