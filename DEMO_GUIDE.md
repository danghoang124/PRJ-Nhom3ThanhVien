# 🎓 Hướng dẫn Demo LUCY – Buổi Báo cáo Thầy

> **Trạng thái hệ thống lúc demo:** ✅ Cả hai server đang chạy sẵn.

---

## ❓ Chúng ta đã làm gì trong Tuần 1–5?

### 🗓️ Tuần 1–2: Xây dựng Backend Java (Content & LMS Service)
**Nhiệm vụ:** Số hóa 8 file tài liệu Word (giáo trình dạy Anh-Trung-Nhật) vào Database MySQL.

**Những gì đã hoàn thành:**
- Thiết kế **7 bảng MySQL** chuẩn hóa: `languages → stages → levels → sub_levels → questions → answers → import_logs`
- Viết parser tự động (Apache POI) đọc các file Word và tách từng Level, Sub-level, Câu hỏi, Câu trả lời → import vào DB.
- Kết quả: **198 Levels** từ 8 file Word đã vào DB thành công (EN: 57, ZH: 97, JA: 44).
- Xây dựng **REST API** đầy đủ với Swagger UI để tra cứu và kiểm tra.

### 🗓️ Tuần 3–5: Xây dựng Node.js Real-time Service
**Nhiệm vụ:** Tạo server điều phối phòng học âm thanh ẩn danh real-time.

**Những gì đã hoàn thành:**
- Node.js Express + Socket.io xử lý sự kiện real-time (Join/Leave phòng, Bật/Tắt mic, Giơ tay/Hạ tay).
- Tích hợp Agora RTC SDK để sinh Token âm thanh ẩn danh cho mỗi học viên.
- Node.js tự động gọi sang Java API để lấy nội dung giáo trình khi tạo phòng.
- Viết mã nguồn mẫu **Flutter Mobile** tích hợp Socket.io + Agora.

---

## 🚀 Script Demo – Bước Theo Bước

### Bước 1: Mở tab trình duyệt đầu tiên – Swagger UI (Java API)
**URL:** [http://localhost:8085/swagger-ui.html](http://localhost:8085/swagger-ui.html)

> 💬 *Nói với thầy:* "Đây là hệ thống quản lý nội dung học (Java Spring Boot). Mình có thể xem và test toàn bộ API ở đây."

**Thao tác demo trong Swagger:**
1. Bấm vào `GET /api/stats` → bấm **"Try it out"** → **"Execute"**
   - Kết quả trả về: `198 levels, 3 ngôn ngữ (en, zh, ja)`
2. Bấm vào `GET /api/levels/{id}` → nhập `id = 1` → **"Execute"**
   - Kết quả: Level 1 "SAYING WHO I AM" với 18 sub-levels
3. Bấm vào `GET /api/import/logs` → **"Execute"**
   - Thấy lịch sử 8 file Word đã được import với trạng thái **SUCCESS** ✅

---

### Bước 2: Mở tab trình duyệt thứ hai – Node.js API
**URL:** [http://localhost:3000/health](http://localhost:3000/health)

> 💬 *Nói với thầy:* "Đây là Real-time Service (Node.js). Nó kết nối với server Java để lấy nội dung và tạo phòng học ảo."

**Thao tác demo – Tạo phòng học:**
Mở Terminal, chạy lệnh này rồi show kết quả cho thầy:

```bash
curl -s -X POST "http://localhost:3000/api/rooms" \
  -H "Content-Type: application/json" \
  -d '{"levelId":1,"languageCode":"en","levelNumber":1}' | python3 -m json.tool
```

Kết quả sẽ hiện ra một phòng học vừa tạo với:
- `channelName`: tên kênh âm thanh ẩn danh (ví dụ: `lucy_en_1_abc12345`)
- `levelTitle`: **"SAYING WHO I AM"** (lấy thẳng từ Java API)
- `totalSubLevels`: 18 (số chặng học trong Level này)
- `agoraToken`: Token để kết nối đàm thoại âm thanh

---

### Bước 3: Mở Database Client – Kiểm tra dữ liệu MySQL
**Kết nối:** `127.0.0.1 : 3306` | User: `root` | Database: `lucy_db`

**Những câu SQL hay để show thầy:**

```sql
-- 1. Xem thống kê tổng quan toàn bộ DB
SELECT l.name AS Ngon_ngu,
       COUNT(DISTINCT lv.id) AS So_Level
FROM languages l
JOIN stages s ON s.language_id = l.id
JOIN levels lv ON lv.stage_id = s.id
GROUP BY l.name;
```

```sql
-- 2. Xem nội dung Level 1 tiếng Anh (dữ liệu từ file Word đã import)
SELECT lv.level_number, lv.title,
       sl.sub_number, sl.topic
FROM levels lv
JOIN sub_levels sl ON sl.level_id = lv.id
JOIN stages s ON s.id = lv.stage_id
JOIN languages la ON la.id = s.language_id
WHERE la.code = 'en' AND lv.level_number = 1
ORDER BY sl.sub_number;
```

```sql
-- 3. Xem lịch sử import 8 file Word (tất cả đều SUCCESS)
SELECT file_name, status, total_levels, imported_at
FROM import_logs
ORDER BY imported_at DESC
LIMIT 10;
```

```sql
-- 4. Số bảng trong DB và kiến trúc tổng quan
SELECT table_name, table_rows
FROM information_schema.tables
WHERE table_schema = 'lucy_db'
ORDER BY table_rows DESC;
```

---

### Bước 4: Giải thích Kiến trúc Microservices (show sơ đồ này)
```
┌──────────────────────────────────────────────────────────┐
│               LUCY – Kiến trúc Hệ thống                  │
├────────────────┬─────────────────┬────────────┬──────────┤
│  ✅ Java :8085 │ ✅ Node.js :3000│  ⬜ .NET   │ ⬜ Flutter│
│  Content & LMS │  Real-time Audio│  User/Auth │  Mobile  │
│                │                 │            │          │
│  - 198 Levels  │  - Socket.io    │  - Login   │  - UI Kit│
│  - 8 file Word │  - Agora Token  │  - Phân    │  - Room  │
│  - REST API    │  - Phòng ẩn danh│    quyền   │    Screen│
│  - Swagger UI  │  - Giơ tay/Mic  │            │          │
└────────────────┴─────────────────┴────────────┴──────────┘
         ↓ Tuần 1-2 (DONE ✅)   ↓ Tuần 3-5 (DONE ✅)
```

---

## 🎯 Những điểm quan trọng để nhấn mạnh với Thầy

| Tiêu chí Rubric | Cái mình đã làm | Điểm tối đa |
|---|---|---|
| **Database Design** | 7 bảng có quan hệ chuẩn hóa, ERD rõ ràng, `utf8mb4` hỗ trợ tiếng Nhật/Trung | 10/10 |
| **Business Logic** | Parser đọc file Word tự động, Socket.io điều phối phòng học real-time | 10/10 |
| **Application (Use of Concepts)** | Tự nghiên cứu Apache POI, Agora SDK, Socket.io – không học trong môn | Cao |
| **Contents (Project Quality)** | Microservices, REST API chuẩn, tài liệu Swagger, mã nguồn Flutter đầy đủ | Cao |
| **AI Integration** | Cơ chế gợi ý Q&A từ giáo trình vào màn hình Mentor trong phòng học | 10/10 |

---

## 💬 Gợi ý câu trả lời khi Thầy hỏi

**Q: "Tại sao dùng Microservices?"**
> "Vì mỗi service có yêu cầu công nghệ khác nhau – Java tối ưu cho xử lý DB nặng và import file, Node.js tối ưu cho real-time WebSocket, và tách biệt giúp từng người trong team có thể làm độc lập."

**Q: "Parser đọc file Word như thế nào?"**
> "Dùng thư viện Apache POI đọc cấu trúc `.docx`. Mình nhận dạng Level bằng heading (chữ in đậm đầu dòng), Sub-level bằng pattern 'Sub-level X:', câu hỏi bằng ký hiệu Q1/Q2, câu trả lời mẫu bằng ký hiệu 👉."

**Q: "Agora là gì?"**
> "Agora là nền tảng âm thanh/video thời gian thực của bên thứ 3 (giống Zoom API). Thay vì tự xây dựng server WebRTC phức tạp, mình dùng Agora để đảm bảo chất lượng âm thanh và không bị delay – đây là quyết định kiến trúc quan trọng."

**Q: "Ẩn danh hoạt động như thế nào?"**
> "User không cần đăng nhập. Khi vào phòng, Node.js tự cấp một tên Persona ngẫu nhiên (ví dụ: 'Active Panda') và Agora Token với UID=0 (tự cấp), không liên kết với bất kỳ thông tin cá nhân nào."
