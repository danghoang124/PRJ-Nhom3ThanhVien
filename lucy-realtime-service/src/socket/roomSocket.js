/**
 * roomSocket.js – Xử lý toàn bộ Socket.io events cho phòng học real-time
 *
 * Events (Client → Server):
 *   room:join        { roomId, agoraUid }
 *   room:leave       {}
 *   mic:toggle       { isMicOn: boolean }
 *   hand:raise       {}
 *   hand:lower       {}
 *   sublevel:next    { roomId }   ← chỉ Mentor mới gửi được
 *
 * Events (Server → Client):
 *   room:joined      { room, user, agoraToken }
 *   room:updated     { room }
 *   user:joined      { user }
 *   user:left        { persona }
 *   mic:changed      { persona, isMicOn }
 *   hand:changed     { persona, isHandRaised }
 *   sublevel:changed { currentSubLevel, totalSubLevels, room }
 *   error            { message }
 */
const { generateAgoraToken } = require('../utils/agoraToken');
const { verifySocketToken } = require('../middleware/auth');

module.exports = function setupRoomSocket(io, roomManager) {

    io.use((socket, next) => {
        const token = socket.handshake.auth?.token || socket.handshake.query?.token;
        if (!token) {
            return next(new Error('Authentication error: Token required'));
        }
        const user = verifySocketToken(socket);
        if (!user) {
            return next(new Error('Authentication error: Invalid token'));
        }
        socket.user = user;
        next();
    });

    io.on('connection', (socket) => {
        console.log(`🔌 User connected: ${socket.id} (${socket.user?.email || 'anonymous'})`);

        // ── room:join ─────────────────────────────────────────
        socket.on('room:join', ({ roomId, agoraUid = 0 }) => {
            const room = roomManager.getRoom(roomId);
            if (!room) {
                return socket.emit('error', { message: `Phòng ${roomId} không tồn tại.` });
            }

            // Tạo Agora token cho user này
            const tokenData = generateAgoraToken(room.channelName, agoraUid);

            // Thêm user vào room
            const userEmail = socket.user['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] || socket.user.email;
            const userRole = socket.user['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] || socket.user.role;
            const result = roomManager.joinRoom(roomId, socket.id, tokenData.uid, userEmail, userRole);
            if (!result) {
                return socket.emit('error', { message: 'Không thể vào phòng.' });
            }

            const { user } = result;

            // Vào Socket.io room (để broadcast)
            socket.join(roomId);

            // Thông báo cho user mới
            socket.emit('room:joined', {
                room      : result.room,
                user,
                agoraToken: tokenData,
            });

            // Thông báo cho mọi người trong phòng
            socket.to(roomId).emit('user:joined', {
                persona : user.persona,
                role    : user.role,
                isMicOn : user.isMicOn,
            });

            // Broadcast trạng thái phòng mới
            io.to(roomId).emit('room:updated', { room: result.room });

            console.log(`👤 ${user.persona} vào phòng ${roomId} (Level ${result.room.levelNumber})`);
        });

        // ── room:leave ────────────────────────────────────────
        socket.on('room:leave', () => {
            _handleLeave(socket, roomManager, io);
        });

        socket.on('disconnect', () => {
            _handleLeave(socket, roomManager, io);
            console.log(`❌ User disconnected: ${socket.id}`);
        });

        // ── mic:toggle ─────────────────────────────────────────
        socket.on('mic:toggle', ({ isMicOn }) => {
            const result = roomManager.toggleMic(socket.id, isMicOn);
            if (!result) return;

            const { room, user } = result;
            io.to(room.id).emit('mic:changed', {
                persona: user.persona,
                isMicOn: user.isMicOn,
            });
        });

        // ── hand:raise / hand:lower ────────────────────────────
        socket.on('hand:raise', () => {
            const result = roomManager.toggleHand(socket.id, true);
            if (!result) return;
            const { room, user } = result;
            io.to(room.id).emit('hand:changed', { persona: user.persona, isHandRaised: true });
            console.log(`✋ ${user.persona} giơ tay trong phòng ${room.id}`);
        });

        socket.on('hand:lower', () => {
            const result = roomManager.toggleHand(socket.id, false);
            if (!result) return;
            const { room, user } = result;
            io.to(room.id).emit('hand:changed', { persona: user.persona, isHandRaised: false });
        });

        // ── sublevel:next (chuyển Sub-level) ──────────────────
        socket.on('sublevel:next', ({ roomId }) => {
            const updatedRoom = roomManager.nextSubLevel(roomId);
            if (!updatedRoom) return;

            io.to(roomId).emit('sublevel:changed', {
                currentSubLevel: updatedRoom.currentSubLevel,
                totalSubLevels : updatedRoom.totalSubLevels,
                status         : updatedRoom.status,
                room           : updatedRoom,
            });

            if (updatedRoom.status === 'ended') {
                io.to(roomId).emit('room:ended', {
                    message: '🎉 Buổi học đã kết thúc! Cảm ơn mọi người đã tham gia.',
                    room   : updatedRoom,
                });
            }
            console.log(`⏭️  Phòng ${roomId} → Sub-level ${updatedRoom.currentSubLevel}`);
        });
    });
};

// ── Helper: xử lý user rời phòng ─────────────────────────
function _handleLeave(socket, roomManager, io) {
    const room = roomManager.getRoomOfUser(socket.id);
    if (!room) return;

    const user = room.users.get(socket.id);
    const persona = user ? user.persona : 'Unknown';

    const updatedRoom = roomManager.leaveRoom(socket.id);
    socket.leave(room.id);

    if (updatedRoom) {
        io.to(room.id).emit('user:left', { persona });
        io.to(room.id).emit('room:updated', { room: updatedRoom });
    }
    console.log(`🚪 ${persona} rời phòng ${room.id}`);
}
