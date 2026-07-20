# LUCY Content Service

> **Java Spring Boot** – Số hóa 8 file Word (LISA/Chinese/Japanese) vào MySQL  
> Cung cấp REST API cho hệ thống LUCY (Node.js / Flutter)

---

## ⚙️ Yêu cầu môi trường

| Tool | Version |
|------|---------|
| JDK  | 17+     |
| Maven | 3.8+  |
| MySQL | 8.x   |
| IDE  | IntelliJ / NetBeans / VSCode |

---

## 🗄️ Bước 1 – Tạo MySQL Database

Mở MySQL Workbench hoặc terminal, chạy:

```sql
CREATE DATABASE lucy_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
```

Sau đó chạy toàn bộ file schema:

```bash
mysql -u root -p lucy_db < src/main/resources/schema.sql
```

---

## ⚙️ Bước 2 – Cấu hình kết nối

Sửa file `src/main/resources/application.properties`:

```properties
spring.datasource.url=jdbc:mysql://localhost:3306/lucy_db?useUnicode=true&characterEncoding=UTF-8
spring.datasource.username=root
spring.datasource.password=YOUR_PASSWORD_HERE   ← đổi thành mật khẩu MySQL của bạn
```

---

## ▶️ Bước 3 – Chạy ứng dụng

```bash
# Build
mvn clean install -DskipTests

# Chạy bình thường (không import)
mvn spring-boot:run

# Chạy + tự động import 8 file Word ngay khi khởi động
mvn spring-boot:run -Dspring-boot.run.profiles=import
```

Ứng dụng chạy tại: **http://localhost:8085**

---

## 📄 Bước 4 – Import dữ liệu

### Cách A: Bulk import qua API (nhanh nhất)

```bash
curl -X POST "http://localhost:8085/api/import/bulk" \
     -d "folderPath=/Users/haidang/Downloads/PRJ/Language"
```

### Cách B: Import từng file qua Swagger UI

1. Mở **http://localhost:8085/swagger-ui.html**
2. Tìm endpoint `POST /api/import/word`
3. Upload file `.docx`, chọn `langCode` và `stageNumber`

### Cách C: Auto import khi start (profile import)

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=import \
    -Dlucky.language.folder=/Users/haidang/Downloads/PRJ/Language
```

---

## 📡 API Endpoints

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| `GET`  | `/api/languages` | Danh sách 3 ngôn ngữ |
| `GET`  | `/api/languages/en/levels` | Tất cả levels tiếng Anh |
| `GET`  | `/api/languages/zh/levels` | Tất cả levels tiếng Trung |
| `GET`  | `/api/languages/ja/levels` | Tất cả levels tiếng Nhật |
| `GET`  | `/api/levels/{id}` | Nội dung đầy đủ 1 level |
| `GET`  | `/api/stats` | Thống kê DB |
| `POST` | `/api/import/word` | Upload 1 file Word |
| `POST` | `/api/import/bulk` | Import toàn bộ 8 file |
| `GET`  | `/api/import/logs` | Lịch sử import |

---

## 🗂️ Cấu trúc project

```
lucy-content-service/
├── pom.xml
└── src/main/
    ├── java/com/lucy/content/
    │   ├── LucyContentApplication.java   ← Main class
    │   ├── entity/                        ← JPA Entities (6 bảng)
    │   ├── repository/                    ← Spring Data JPA
    │   ├── service/
    │   │   ├── WordImportService.java     ← Apache POI đọc .docx
    │   │   ├── BulkImportService.java     ← Import 8 file tự động
    │   │   └── ContentService.java        ← Cung cấp data cho API
    │   ├── controller/
    │   │   ├── ContentController.java     ← GET /api/levels...
    │   │   └── ImportController.java      ← POST /api/import...
    │   ├── dto/                           ← Response DTOs
    │   └── config/SwaggerConfig.java      ← Swagger UI
    └── resources/
        ├── application.properties
        └── schema.sql                     ← MySQL Schema
```

---

## ✅ Kiểm tra hoàn thành

```bash
# Kiểm tra DB có dữ liệu chưa
curl http://localhost:8085/api/stats

# Lấy level 1 tiếng Anh
curl http://localhost:8085/api/levels/1

# Xem log import
curl http://localhost:8085/api/import/logs
```

---

*LUCY Dev Team – PRJ301 @ FPT University*
