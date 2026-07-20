# LUCY Project – Progress & Setup Guide

## Trạng Thái Hiện Tại

| Service | Tech Stack | Port | Trạng Thái |
|---------|-----------|------|------------|
| `lucy-content-service` | Java Spring Boot 3.2.5 | 8085 | ✅ Hoàn chỉnh + JWT auth |
| `lucy-realtime-service` | Node.js + Express + Socket.io | 3000 | ✅ Hoàn chỉnh + JWT auth |
| `lucy-auth-service` | .NET 7.0 ASP.NET Core | 5197 | ✅ Mới xây dựng |
| `lucy-mobile-flutter` | Flutter/Dart | - | ✅ Hoàn chỉnh + Auth flow |

## Kiến Trúc Tổng Quan

```
┌─────────────────────────────────────────────────────────────┐
│                    LUCY Mobile App (Flutter)                 │
│  - Login/Register → .NET Auth Service (:5197)              │
│  - Level List → Java Content Service (:8085)               │
│  - Real-time Room → Node.js Service (:3000) + Agora        │
└─────────────────────────────────────────────────────────────┘
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────────┐
│ .NET Auth    │   │ Java Content │   │ Node.js Realtime │
│ Service      │   │ Service      │   │ Service          │
│ :5197        │   │ :8085        │   │ :3000            │
│              │   │              │   │                  │
│ - JWT Issue  │   │ - Content    │   │ - Socket.io      │
│ - User CRUD  │   │ - Import     │   │ - Agora Token    │
│ - Swagger    │   │ - Swagger    │   │ - Room Mgmt      │
└──────┬───────┘   └──────┬───────┘   └──────────────────┘
       │                  │
       ▼                  ▼
┌──────────────────────────────────────┐
│          MySQL Database              │
│          lucy_db                     │
│  - users (Auth service)             │
│  - languages, stages, levels...     │
│    (Content service)                │
└──────────────────────────────────────┘
```

## Hướng Dẫn Chạy Từng Service

### Prerequisites
- Java 21+
- Node.js 18+
- .NET 7.0 SDK
- MySQL 8.x
- Flutter SDK (hoặc Android Studio)

### 1. MySQL Database

```sql
-- Tạo database và chạy schema
mysql -u root -p < lucy-content-service/src/main/resources/schema.sql

-- Tạo bảng users cho Auth service
mysql -u root -p < lucy-auth-service/schema.sql
```

### 2. Java Content Service (Port 8085)

```bash
cd lucy-content-service

# Set environment variables (hoặc sửa application.properties)
export MYSQL_PASSWORD=your_mysql_password
export JWT_SECRET=LUCY_SuperSecretKey_2024_MustBe32CharsLong!

# Chạy
mvn spring-boot:run

# Swagger UI: http://localhost:8085/swagger-ui.html
# Health: http://localhost:8085/api/stats
```

### 3. .NET Auth Service (Port 5197)

```bash
cd lucy-auth-service

# Set environment variables
export MYSQL__PASSWORD=your_mysql_password
export JWT__KEY=LUCY_SuperSecretKey_2024_MustBe32CharsLong!

# Chạy
dotnet run

# Swagger UI: http://localhost:5197/swagger-ui.html
# Test Register: POST http://localhost:5197/api/auth/register
# Test Login: POST http://localhost:5197/api/auth/login
```

### 4. Node.js Realtime Service (Port 3000)

```bash
cd lucy-realtime-service

# Install dependencies
npm install

# Set environment variables (hoặc sửa .env)
export AGORA_APP_ID=your_agora_app_id
export AGORA_APP_CERTIFICATE=your_agora_app_certificate
export JWT_SECRET=LUCY_SuperSecretKey_2024_MustBe32CharsLong!

# Chạy
npm start

# Health: http://localhost:3000/health
# Demo: http://localhost:3000/demo
```

### 5. Flutter Mobile App

```bash
cd lucy-mobile-flutter

# Install dependencies
flutter pub get

# Chạy trên simulator
flutter run

# Hoặc build APK
flutter build apk
```

## API Endpoints

### Auth Service (.NET :5197)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/auth/register` | ❌ | Đăng ký tài khoản |
| POST | `/api/auth/login` | ❌ | Đăng nhập, trả JWT |
| GET | `/api/users/me` | ✅ | Thông tin user hiện tại |
| GET | `/api/users/verify` | ❌ | Verify JWT token |
| GET | `/api/users` | ✅ (admin) | Danh sách users |

### Content Service (Java :8085)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/languages` | ❌ | Danh sách ngôn ngữ |
| GET | `/api/languages/{code}/levels` | ❌ | Levels theo ngôn ngữ |
| GET | `/api/levels/{levelId}` | ❌ | Nội dung level |
| GET | `/api/stats` | ❌ | Thống kê dữ liệu |
| POST | `/api/import/word` | ✅ | Import file Word |
| POST | `/api/import/bulk` | ✅ | Bulk import |
| GET | `/api/import/logs` | ❌ | Lịch sử import |

### Realtime Service (Node.js :3000)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/health` | ❌ | Health check |
| GET | `/api/rooms` | ❌ | Danh sách phòng |
| POST | `/api/rooms` | ✅ JWT | Tạo phòng mới |
| GET | `/api/rooms/:id` | ❌ | Chi tiết phòng |
| DELETE | `/api/rooms/:id` | ❌ | Xóa phòng |
| POST | `/api/agora/token` | ❌ | Tạo Agora token |

### Socket.io Events

| Event | Direction | Auth | Description |
|-------|-----------|------|-------------|
| `room:join` | Client→Server | ✅ JWT | Vào phòng |
| `room:leave` | Client→Server | - | Rời phòng |
| `mic:toggle` | Client→Server | - | Bật/tắt mic |
| `hand:raise` | Client→Server | - | Giơ tay |
| `sublevel:next` | Client→Server | - | Chuyển chặng |

## JWT Authentication

### Flow

1. **Register/Login**: Gọi `POST /api/auth/register` hoặc `/api/auth/login`
2. **Get Token**: Server trả về `{ token, email, role, expiresAt }`
3. **Use Token**: Gửi trong header `Authorization: Bearer <token>`
4. **Socket.io**: Gửi token qua `socket.handshake.auth.token`

### Shared Secret

Cả 3 services dùng cùng 1 JWT secret:
```
LUCY_SuperSecretKey_2024_MustBe32CharsLong!
```

**LƯU Ý**: Chỉ dùng cho development. Trong production, phải sinh secret ngẫu nhiên và lưu trong environment variables.

## Bảo Mật

### Secrets Management

| Secret | File | Trạng thái |
|--------|------|------------|
| MySQL Password | `application.properties` | ⚠️ Đã tách env var |
| MySQL Password | `.env` | ✅ Đã gitignore |
| Agora App ID | `.env` | ✅ Đã gitignore |
| Agora Certificate | `.env` | ✅ Đã gitignore |
| JWT Secret | `.env` | ✅ Đã gitignore |

### .gitignore

Đã thêm vào root và từng service:
- `.env` files
- `bin/obj/` (.NET)
- `target/` (Java)
- `node_modules/` (Node.js)
- IDE files

## Database Schema

### Tables (shared `lucy_db`)

```sql
-- Content Service tables
languages (id, code, name, created_at)
stages (id, language_id, stage_number, name, cefr_range, ...)
levels (id, stage_id, level_number, title, duration_min, ...)
sub_levels (id, level_id, sub_number, topic, duration_min, ...)
questions (id, sub_level_id, question_order, question_text)
answers (id, question_id, answer_order, answer_text, is_sample)
import_logs (id, file_name, language_code, stage_number, ...)

-- Auth Service table
users (id, email, password_hash, role, created_at)
```

## Còn Thiếu (Known Issues)

### Chưa Test Được Thực Tế

1. **MySQL Connection**: Cần MySQL đang chạy trên localhost:3306
2. **Agora SDK**: Cần Agora App ID thật để test audio real-time
3. **Flutter Build**: Cần Flutter SDK cài đặt để build/run
4. **.NET Build**: Đã build thành công (`dotnet build` ✅)

### Cần Hoàn Thiện Thêm

1. **Refresh Token**: Hiện tại chỉ có access token, chưa có refresh token
2. **Password Reset**: Chưa có tính năng quên mật khẩu
3. **Email Verification**: Chưa xác thực email khi đăng ký
4. **Rate Limiting**: Chưa có giới hạn request
5. **Logging**: Chưa có centralized logging
6. **Docker**: Chưa có Docker Compose để chạy đồng thời

### Testing

Chưa có automated tests. Cần viết:
- Unit tests cho .NET AuthService
- Integration tests cho REST APIs
- E2E tests cho Flutter app

## Chạy Đồng Thời Tất Cả

Terminal 1 (Java):
```bash
cd lucy-content-service && mvn spring-boot:run
```

Terminal 2 (.NET):
```bash
cd lucy-auth-service && dotnet run --launch-profile http
```

Terminal 3 (Node.js):
```bash
cd lucy-realtime-service && npm start
```

Terminal 4 (Flutter):
```bash
cd lucy-mobile-flutter && flutter run
```

Hoặc sử dụng Docker Compose (chưa có, cần tạo thêm).

---

**Cập nhật lần cuối**: 2026-07-14
**Phiên bản**: 1.0.0
