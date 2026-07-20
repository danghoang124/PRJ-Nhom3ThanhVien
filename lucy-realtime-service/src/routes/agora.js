const express     = require('express');
const router      = express.Router();
const { generateAgoraToken } = require('../utils/agoraToken');

/**
 * POST /api/agora/token
 * Body: { channelName, uid?, role? }
 * → Trả về Agora RTC token cho Flutter/Mobile join kênh âm thanh
 */
router.post('/token', (req, res) => {
    const { channelName, uid = 0, role = 'PUBLISHER' } = req.body;

    if (!channelName) {
        return res.status(400).json({ error: 'channelName là bắt buộc' });
    }

    const tokenData = generateAgoraToken(channelName, uid, role);
    return res.json(tokenData);
});

/**
 * GET /api/agora/token?channelName=xxx
 * → Tiện lợi hơn để test nhanh
 */
router.get('/token', (req, res) => {
    const { channelName, uid = 0, role = 'PUBLISHER' } = req.query;

    if (!channelName) {
        return res.status(400).json({ error: 'channelName là bắt buộc' });
    }

    const tokenData = generateAgoraToken(channelName, parseInt(uid), role);
    return res.json(tokenData);
});

module.exports = router;
