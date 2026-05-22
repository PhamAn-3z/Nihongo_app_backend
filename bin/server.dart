import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  // 1. Khởi tạo bộ định tuyến (Router) để quản lý các đường link API
  final router = Router();

  // 2. Định nghĩa một đường link API chạy thử (GET Method)
  router.get('/api/v1/status', (Request request) {
    final responseData = {
      "status": "success",
      "message": "Kết nối đến Động Docker Backend thành công mỹ mãn!",
      "timestamp": DateTime.now().toIso8601String()
    };
    // Trả về dữ liệu dạng JSON cho người gọi
    return Response.ok(
      jsonEncode(responseData),
      headers: {'content-type': 'application/json'},
    );
  });

  // 3. Định nghĩa API Đăng nhập mẫu (POST Method)
  router.post('/api/v1/auth/login', (Request request) async {
    // Đọc dữ liệu tài khoản/mật khẩu mà app Flutter gửi lên
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final String email = data['email'] ?? '';
    final String password = data['password'] ?? '';

    // Logic kiểm tra tài khoản giả lập (Tạm thời test chay trước khi chọc vào Supabase)
    if (email == "admin@gmail.com" && password == "123456") {
      return Response.ok(
        jsonEncode({
          "status": "success",
          "message": "Đăng nhập thành công!",
          "user": {"id": 1, "email": email, "username": "Admin Đẹp Trai"}
        }),
        headers: {'content-type': 'application/json'},
      );
    } else {
      return Response.forbidden(
        jsonEncode({"status": "error", "message": "Sai tài khoản hoặc mật khẩu rồi bạn ơi!"}),
        headers: {'content-type': 'application/json'},
      );
    }
  });

  // 4. Cấu hình để Server Docker có thể lắng nghe từ mọi địa chỉ IP (0.0.0.0)
  // Trong môi trường Docker, bắt buộc phải dùng '0.0.0.0' thay vì 'localhost'
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router);
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);

  print('🚀 THÀNH CÔNG: Xe tải Docker Backend đang nổ máy tại cổng: http://${server.address.host}:${server.port}');
}