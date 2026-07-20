# Danh Sách Tài Khoản Thử Nghiệm (LUCY EdTech)

Dưới đây là danh sách các tài khoản đã được khởi tạo trong cơ sở dữ liệu để phục vụ việc kiểm thử hệ thống.

| Vai trò | Email | Mật khẩu | Quyền hạn (Role) | Mô tả |
|---|---|---|---|---|
| **Admin** | `admin@lucy.com` | `Lucy@123` | `admin` | Có toàn quyền quản lý, bao gồm quyền import dữ liệu qua Java Content Service. |
| **Test User** | `test@lucy.com` | `Lucy@123` | `user` | Tài khoản kiểm thử mặc định dùng cho học viên. |
| **Student** | `student@lucy.com` | `Lucy@123` | `user` | Tài khoản học viên thông thường dùng để tham gia phòng học trực tuyến. |

---

### Hướng dẫn sử dụng:
1. Sử dụng các tài khoản trên để đăng nhập trên ứng dụng di động/web Flutter (`http://localhost:4200`).
2. Các tài khoản được lưu trong bảng `users` của cơ sở dữ liệu MySQL `lucy_db`.
3. Bạn cũng có thể đăng ký thêm tài khoản mới trực tiếp từ giao diện Đăng ký của ứng dụng.
