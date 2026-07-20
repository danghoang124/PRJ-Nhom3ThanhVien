const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'LUCY_SuperSecretKey_2024_MustBe32CharsLong!';

/**
 * Middleware xác thực JWT cho REST API
 * Header: Authorization: Bearer <token>
 */
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Token không được cung cấp' });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        return res.status(403).json({ error: 'Token không hợp lệ hoặc đã hết hạn' });
    }
}

/**
 * Xác thực JWT từ socket handshake query
 * Trả về decoded user hoặc null nếu token không hợp lệ
 */
function verifySocketToken(socket) {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    
    if (!token) {
        return null;
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        return decoded;
    } catch (err) {
        return null;
    }
}

module.exports = { authenticateToken, verifySocketToken, JWT_SECRET };
