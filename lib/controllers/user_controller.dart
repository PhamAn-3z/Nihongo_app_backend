import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../repositories/user_repository.dart';

class UserController {
  final UserRepository userRepository;

  UserController(this.userRepository);

  // Hàm xử lý lấy thông tin Profile từ Database dựa trên Token
  Future<Response> getProfile(Request request) async {
    try {
      // 1. Lấy payload từ Middleware đã lưu vào context
      final authPayload = request.context['authPayload'] as Map<String, dynamic>?;
      
      if (authPayload == null) {
        return Response.forbidden(
          jsonEncode({"success": false, "message": "Không tìm thấy thông tin xác thực."}),
          headers: {'content-type': 'application/json'},
        );
      }

      final userId = authPayload['userId'];

      // 2. Truy vấn Database để lấy thông tin mới nhất
      final user = await userRepository.findById(userId);

      if (user == null) {
        return Response.notFound(
          jsonEncode({"success": false, "message": "Không tìm thấy người dùng."}),
          headers: {'content-type': 'application/json'},
        );
      }

      // 3. Trả về các field yêu cầu: user_id, role_id, username, email
      return Response.ok(
        jsonEncode({
          "success": true,
          "data": {
            "user_id": user['user_id'],
            "role_id": user['role_id'],
            "username": user['username'],
            "email": user['email'],
          }
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"success": false, "message": "Lỗi server: $e"}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
