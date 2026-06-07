# Nihongo App Backend

Dự án backend cho ứng dụng học tiếng Nhật (Nihongo App), sử dụng Dart và framework Shelf.

## Tính năng hiện tại
- Kết nối trực tiếp với **Supabase Cloud**.
- Hệ thống Authentication (JWT).
- API cung cấp dữ liệu thật từ database.

## Các API Endpoints

### Public APIs
- `GET /api/v1/decks`: Lấy danh sách bộ thẻ (decks).

### Auth APIs (`/api/v1/auth/`)
- `POST /register`: Đăng ký tài khoản mới (Email, Password, Username).
- `POST /login`: Đăng nhập lấy JWT Token.
- `POST /logout`: Đăng xuất (Yêu cầu Token).

### User APIs (`/api/v1/user/`) - Yêu cầu Bearer Token
- `GET /profile`: Lấy thông tin cá nhân.

## Cách chạy dự án

### 1. Chạy với Dart SDK
Đảm bảo bạn đã cài đặt Dart SDK. Chạy lệnh sau trong terminal:

```bash
dart pub get
dart run bin/server.dart
```

Server sẽ lắng nghe tại cổng `8080`.

### 2. Chạy với Docker
```bash
docker build . -t nihongo-backend
docker run -it -p 8080:8080 nihongo-backend
```

## Cấu trúc mã nguồn
- `bin/server.dart`: Cấu hình server và Middleware.
- `lib/controllers/`: Xử lý logic request/response.
- `lib/services/`: Xử lý logic nghiệp vụ (Auth, JWT).
- `lib/repositories/`: Tương tác trực tiếp với Supabase.
- `lib/routes/`: Định nghĩa các luồng API.
- `lib/middlewares/`: Kiểm tra quyền truy cập (Auth Check).
