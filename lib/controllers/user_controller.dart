import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../repositories/user_repository.dart';

class UserController {
  final UserRepository userRepository;

  UserController(this.userRepository);

  // Lấy thông tin Profile (bao gồm cả bảng user_profiles)
  Future<Response> getProfile(Request request) async {
    try {
      final authPayload = request.context['authPayload'] as Map<String, dynamic>?;
      if (authPayload == null) {
        return Response.forbidden(
          jsonEncode({"success": false, "message": "Không tìm thấy thông tin xác thực."}),
          headers: {'content-type': 'application/json'},
        );
      }

      final userId = authPayload['userId'];
      final user = await userRepository.findById(userId);

      if (user == null) {
        return Response.notFound(
          jsonEncode({"success": false, "message": "Không tìm thấy người dùng."}),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          "success": true,
          "data": {
            "user_id": user['user_id'],
            "username": user['username'],
            "email": user['email'],
            "role_id": user['role_id'],
            "profile": user['user_profiles'], // Thông tin từ bảng user_profiles
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

  // Cập nhật thông tin User Profile (Partial Update)
  Future<Response> updateProfile(Request request) async {
    try {
      final authPayload = request.context['authPayload'] as Map<String, dynamic>?;
      if (authPayload == null) {
        return Response.forbidden(
          jsonEncode({"success": false, "message": "Không tìm thấy thông tin xác thực."}),
          headers: {'content-type': 'application/json'},
        );
      }

      final userId = authPayload['userId'];
      final body = await request.readAsString();
      if (body.isEmpty) {
        return Response.badRequest(body: jsonEncode({"message": "Body không được để trống"}));
      }
      
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Chỉ lọc các field được phép cập nhật theo yêu cầu
      final allowedFields = ['full_name', 'gender', 'date_of_birth', 'phone_number'];
      final Map<String, dynamic> updateData = {};

      for (var field in allowedFields) {
        if (data.containsKey(field)) {
          updateData[field] = data[field];
        }
      }

      if (updateData.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({"success": false, "message": "Không có dữ liệu hợp lệ để cập nhật."}),
          headers: {'content-type': 'application/json'},
        );
      }

      final result = await userRepository.updateProfile(userId, updateData);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Cập nhật thông tin thành công.",
          "data": result
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
