# Project Context: Nihongo App Backend

## 1. Tổng quan dự án (Project Overview)
Dự án này là phần Backend cho ứng dụng học tiếng Nhật (**Nihongo App**). Mục tiêu chính là cung cấp dữ liệu về các bộ thẻ học (flashcards), bài kiểm tra (quizzes) và quản lý người dùng.

## 2. Công nghệ sử dụng (Tech Stack)
- **Ngôn ngữ:** Dart (SDK ^3.11.5)
- **Framework:** [Shelf](https://pub.dev/packages/shelf) & [Shelf Router](https://pub.dev/packages/shelf_router) - Một framework web siêu nhẹ cho Dart.
- **Cơ sở dữ liệu & Backend-as-a-Service:** [Supabase](https://supabase.com/) - Sử dụng Supabase Client để truy vấn dữ liệu thời gian thực.
- **Containerization:** Docker (đã cấu hình Multi-stage build để tối ưu dung lượng).

## 3. Kiến trúc hệ thống (Architecture)
- **Entry Point:** `bin/server.dart` - Nơi khởi tạo kết nối Supabase, định nghĩa các route và chạy server tại cổng `8080`.
- **Controllers/Logic:** 
  - `lib/auth_controller.dart`: Dự kiến dùng để xử lý xác thực người dùng (hiện đang để trống).
- **Data Model:** Dữ liệu được lưu trữ trên Supabase Cloud (bảng `decks`, v.v.).

## 4. Cấu trúc thư mục (Directory Structure)
```text
Nihongo_app_backend/
├── bin/
│   └── server.dart          # Entry point, cấu hình server & routes
├── lib/
│   └── auth_controller.dart  # Logic xử lý xác thực (Auth)
├── test/                    # Các bản kiểm thử (Unit/Integration test)
├── .dockerignore            # Loại bỏ các file không cần thiết khi build Docker
├── Dockerfile               # Cấu hình Multi-stage build cho ứng dụng
├── pubspec.yaml             # Quản lý thư viện (Shelf, Supabase, v.v.)
├── README.md                # Hướng dẫn sử dụng nhanh
└── PROJECT_CONTEXT.md       # Tài liệu bối cảnh dự án (file này)
```

## 5. Trạng thái hiện tại (Current Status)
- [x] Đã thiết lập khung dự án Dart Shelf.
- [x] Đã kết nối thành công với Supabase Cloud.
- [x] API đầu tiên hoàn thành: `GET /api/v1/decks` để lấy danh sách bộ thẻ.
- [x] Đã cấu hình Dockerfile để sẵn sàng triển khai.
- [ ] Cần phát triển thêm các API cho bài học (lessons), từ vựng (vocabularies).
- [ ] Cần hoàn thiện hệ thống xác thực (Authentication).

## 6. Thông tin môi trường (Environment)
- **Port:** 8080
- **Supabase URL:** `https://xdekwfqnhrohydgejhdk.supabase.co`
- **Lưu ý bảo mật:** Anon Key hiện đang hardcode trong `server.dart`, cần chuyển sang `.env` khi deploy chính thức.

---
*Tài liệu này được tạo tự động để tóm tắt bối cảnh dự án.*
