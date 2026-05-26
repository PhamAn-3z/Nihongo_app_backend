# Nihongo App Backend

Dự án backend cho ứng dụng học tiếng Nhật (Nihongo App), sử dụng Dart và framework Shelf.

## Tính năng hiện tại
- Kết nối trực tiếp với **Supabase Cloud**.
- API cung cấp dữ liệu thật từ database.

## Các API Endpoints
- `GET /api/v1/decks`: Lấy danh sách bộ thẻ (decks) từ bảng `decks` trên Supabase.

## Cách chạy dự án

### 1. Chạy với Dart SDK
Đảm bảo bạn đã cài đặt Dart SDK. Chạy lệnh sau trong terminal:

```bash
dart pub get
dart run bin/server.dart
```

Server sẽ lắng nghe tại cổng `8080`. Bạn có thể kiểm tra bằng cách truy cập:
`http://localhost:8080/api/v1/decks`

### 2. Chạy với Docker
Nếu bạn có Docker, hãy sử dụng các lệnh sau:

```bash
docker build . -t nihongo-backend
docker run -it -p 8080:8080 nihongo-backend
```

## Cấu trúc mã nguồn
- `bin/server.dart`: Chứa cấu hình server, kết nối Supabase và định nghĩa router.
- `pubspec.yaml`: Quản lý các dependency (`shelf`, `shelf_router`, `supabase`).
