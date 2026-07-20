# LUCY Real-time Service

> **Node.js + Socket.io + Agora SDK** – Xử lý phòng học âm thanh real-time  
> Kết nối trực tiếp với **Java Content Service** tại `http://localhost:8085`

---

## ⚙️ Yêu cầu môi trường

| Tool    | Version |
|---------|---------|
| Node.js | 18+     |
| npm     | 9+      |

---

## 🚀 Cài đặt & Chạy

```bash
# 1. Vào thư mục
cd lucy-realtime-service

# 2. Cài dependencies
npm install

# 3. Cấu hình .env
# → Sửa AGORA_APP_ID và AGORA_APP_CERTIFICATE (nếu có)
# → Để trống = chạy Dev Mode (dùng token giả để test)

# 4. Chạy development
npm run dev

# 5. Kiểm tra
curl http://localhost:3000/health
```

---

## 📡 REST API Endpoints

| Method | URL | Mô tả |
|--------|-----|-------|
| `GET`  | `/health` | Trạng thái server |
| `POST` | `/api/agora/token` | Tạo Agora RTC token |
| `GET`  | `/api/agora/token?channelName=xxx` | Tạo token (GET) |
| `GET`  | `/api/rooms` | Danh sách phòng |
| `POST` | `/api/rooms` | Tạo phòng mới |
| `GET`  | `/api/rooms/:roomId` | Chi tiết 1 phòng |
| `GET`  | `/api/rooms/:roomId/level-content` | Nội dung Level từ Java |
| `DELETE` | `/api/rooms/:roomId` | Xóa phòng |

---

## 🔌 Socket.io Events

### Client → Server

| Event | Payload | Mô tả |
|-------|---------|-------|
| `room:join` | `{ roomId, agoraUid? }` | Vào phòng |
| `room:leave` | `{}` | Rời phòng |
| `mic:toggle` | `{ isMicOn }` | Bật/tắt mic |
| `hand:raise` | `{}` | Giơ tay |
| `hand:lower` | `{}` | Hạ tay |
| `sublevel:next` | `{ roomId }` | Chuyển Sub-level tiếp |

### Server → Client

| Event | Payload | Mô tả |
|-------|---------|-------|
| `room:joined` | `{ room, user, agoraToken }` | Vào phòng thành công |
| `room:updated` | `{ room }` | Cập nhật trạng thái phòng |
| `user:joined` | `{ persona, role, isMicOn }` | Có user mới vào |
| `user:left` | `{ persona }` | User rời phòng |
| `mic:changed` | `{ persona, isMicOn }` | Ai đó bật/tắt mic |
| `hand:changed` | `{ persona, isHandRaised }` | Ai đó giơ/hạ tay |
| `sublevel:changed` | `{ currentSubLevel, totalSubLevels }` | Chuyển chủ đề |
| `room:ended` | `{ message, room }` | Buổi học kết thúc |
| `error` | `{ message }` | Lỗi |

---

## 🏗️ Cấu trúc project

```
lucy-realtime-service/
├── .env                        ← Config (Agora App ID, port...)
├── package.json
└── src/
    ├── server.js               ← Express + Socket.io entry point
    ├── managers/
    │   └── RoomManager.js      ← Quản lý phòng trong memory
    ├── routes/
    │   ├── agora.js            ← POST /api/agora/token
    │   └── rooms.js            ← CRUD /api/rooms
    ├── socket/
    │   └── roomSocket.js       ← Xử lý tất cả Socket.io events
    └── utils/
        └── agoraToken.js       ← Tạo Agora RTC token
```

---

## 🔗 Tích hợp với Java Content Service

Khi tạo phòng (`POST /api/rooms`), Node.js tự động gọi:
```
GET http://localhost:8085/api/levels/{levelId}
```
→ Lấy tên Level, số SubLevel, danh sách câu hỏi để hiển thị trong phòng.

---

## 📱 Test bằng Socket.io Client

```javascript
const io = require('socket.io-client');
const socket = io('http://localhost:3000');

// 1. Tạo phòng trước (REST)
// POST /api/rooms { levelId: 1, languageCode: "en", levelNumber: 1 }

// 2. Vào phòng
socket.emit('room:join', { roomId: 'abc12345' });

// 3. Nhận token Agora để join kênh âm thanh
socket.on('room:joined', ({ room, user, agoraToken }) => {
    console.log('Joined as:', user.persona);
    console.log('Agora token:', agoraToken.token);
    // → Dùng agoraToken.token để join Agora channel trên Flutter
});

// 4. Giơ tay
socket.emit('hand:raise');

// 5. Bật mic
socket.emit('mic:toggle', { isMicOn: true });
```

---

## 🔑 Cấu hình Agora (Production)

1. Đăng ký tại [https://www.agora.io](https://www.agora.io) (miễn phí 10,000 phút/tháng)
2. Tạo project → lấy **App ID** và **App Certificate**
3. Điền vào `.env`:
```
AGORA_APP_ID=your_app_id_here
AGORA_APP_CERTIFICATE=your_certificate_here
```

> ⚠️ **Dev Mode**: Nếu để trống `AGORA_APP_ID`, server vẫn chạy bình thường  
> và trả về token giả (`DEV_TOKEN_...`) để test luồng giao diện.

---

*LUCY Dev Team – PRJ301 @ FPT University*
