const { v4: uuidv4 } = require('uuid');

/**
 * RoomManager – Quản lý toàn bộ phòng học real-time trong bộ nhớ
 *
 * Cấu trúc 1 room:
 * {
 *   id          : 'uuid',
 *   channelName : 'lucy_en_1_abc123',   ← dùng làm Agora channel name
 *   levelId     : 1,
 *   languageCode: 'en',
 *   levelNumber : 1,
 *   levelTitle  : 'SAYING WHO I AM',
 *   currentSubLevel: 1,
 *   totalSubLevels : 6,
 *   status      : 'waiting' | 'active' | 'ended',
 *   createdAt   : Date,
 *   users       : Map<socketId, UserInfo>
 * }
 *
 * UserInfo:
 * {
 *   socketId    : string,
 *   agoraUid    : number,
 *   persona     : 'Ghost_123',   ← tên ẩn danh
 *   role        : 'member' | 'mentor',
 *   isMicOn     : boolean,
 *   isHandRaised: boolean,
 *   joinedAt    : Date,
 * }
 */
class RoomManager {
    constructor() {
        this.rooms = new Map(); // roomId → room
    }

    // ── Tạo phòng mới ────────────────────────────────────────
    createRoom({ levelId, languageCode, levelNumber, levelTitle, totalSubLevels, subLevels, creatorEmail }) {
        const roomId      = uuidv4().slice(0, 8);
        const channelName = `lucy_${languageCode}_${levelNumber}_${roomId}`;

        const room = {
            id           : roomId,
            channelName,
            levelId,
            languageCode,
            levelNumber,
            levelTitle   : levelTitle || `Level ${levelNumber}`,
            currentSubLevel: 1,
            totalSubLevels : totalSubLevels || 6,
            subLevels      : subLevels || [],
            creatorEmail   : creatorEmail || '',
            status       : 'waiting',
            createdAt    : new Date(),
            users        : new Map(),
        };

        this.rooms.set(roomId, room);
        return room;
    }

    // ── Lấy phòng ─────────────────────────────────────────────
    getRoom(roomId) {
        return this.rooms.get(roomId) || null;
    }

    getRoomByChannel(channelName) {
        for (const room of this.rooms.values()) {
            if (room.channelName === channelName) return room;
        }
        return null;
    }

    // ── Danh sách phòng (cho REST API) ────────────────────────
    listRooms({ languageCode, status } = {}) {
        let rooms = Array.from(this.rooms.values());
        if (languageCode) rooms = rooms.filter(r => r.languageCode === languageCode);
        if (status)       rooms = rooms.filter(r => r.status === status);
        return rooms.map(r => this._serialize(r));
    }

    // ── User vào phòng ────────────────────────────────────────
    joinRoom(roomId, socketId, agoraUid, userEmail, userRole) {
        const room = this.rooms.get(roomId);
        if (!room) return null;

        const persona = this._generatePersona();
        
        let role = 'member';
        if (room.creatorEmail === userEmail || userRole === 'admin' || userRole === 'mentor') {
            role = 'mentor';
        }

        const user = {
            socketId,
            agoraUid,
            persona,
            role,
            isMicOn     : false,
            isHandRaised: false,
            joinedAt    : new Date(),
        };
        room.users.set(socketId, user);
        if (room.status === 'waiting' && room.users.size >= 1) {
            room.status = 'active';
        }
        return { room: this._serialize(room), user };
    }

    // ── User rời phòng ────────────────────────────────────────
    leaveRoom(socketId) {
        for (const room of this.rooms.values()) {
            if (room.users.has(socketId)) {
                room.users.delete(socketId);
                if (room.users.size === 0) {
                    room.status = 'waiting';
                }
                return this._serialize(room);
            }
        }
        return null;
    }

    // ── Tìm phòng của user ─────────────────────────────────────
    getRoomOfUser(socketId) {
        for (const room of this.rooms.values()) {
            if (room.users.has(socketId)) return room;
        }
        return null;
    }

    // ── Toggle mic ─────────────────────────────────────────────
    toggleMic(socketId, isMicOn) {
        const room = this.getRoomOfUser(socketId);
        if (!room) return null;
        const user = room.users.get(socketId);
        user.isMicOn = isMicOn;
        return { room: this._serialize(room), user };
    }

    // ── Giơ tay / hạ tay ──────────────────────────────────────
    toggleHand(socketId, isRaised) {
        const room = this.getRoomOfUser(socketId);
        if (!room) return null;
        const user = room.users.get(socketId);
        user.isHandRaised = isRaised;
        return { room: this._serialize(room), user };
    }

    // ── Chuyển Sub-level tiếp theo ────────────────────────────
    nextSubLevel(roomId) {
        const room = this.rooms.get(roomId);
        if (!room) return null;
        if (room.currentSubLevel < room.totalSubLevels) {
            room.currentSubLevel++;
        } else {
            room.status = 'ended';
        }
        return this._serialize(room);
    }

    // ── Thống kê ──────────────────────────────────────────────
    getRoomCount()   { return this.rooms.size; }
    getTotalUsers()  {
        let total = 0;
        for (const r of this.rooms.values()) total += r.users.size;
        return total;
    }

    // ── Helpers ───────────────────────────────────────────────
    _generatePersona() {
        const adjectives = ['Swift', 'Brave', 'Calm', 'Daring', 'Epic', 'Fierce', 'Gentle', 'Happy'];
        const nouns      = ['Panda', 'Eagle', 'Tiger', 'Fox', 'Wolf', 'Bear', 'Hawk', 'Owl'];
        const adj  = adjectives[Math.floor(Math.random() * adjectives.length)];
        const noun = nouns[Math.floor(Math.random() * nouns.length)];
        const num  = Math.floor(Math.random() * 999) + 1;
        return `${adj}${noun}#${num}`;
    }

    _serialize(room) {
        return {
            id             : room.id,
            channelName    : room.channelName,
            levelId        : room.levelId,
            languageCode   : room.languageCode,
            levelNumber    : room.levelNumber,
            levelTitle     : room.levelTitle,
            currentSubLevel: room.currentSubLevel,
            totalSubLevels : room.totalSubLevels,
            subLevels      : room.subLevels || [],
            creatorEmail   : room.creatorEmail || '',
            status         : room.status,
            createdAt      : room.createdAt,
            userCount      : room.users.size,
            users          : Array.from(room.users.values()).map(u => ({
                persona     : u.persona,
                role        : u.role,
                isMicOn     : u.isMicOn,
                isHandRaised: u.isHandRaised,
            })),
        };
    }
}

module.exports = new RoomManager(); // Singleton
