import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../repositories/user_repository.dart';

class UserController {
  final UserRepository userRepository;

  UserController(this.userRepository);

  // Lấy thông tin Profile
  Future<Response> getProfile(Request request) async {
    try {
      final authPayload = request.context['authPayload'] as Map<String, dynamic>?;
      if (authPayload == null) {
        return Response.forbidden(jsonEncode({"message": "Unauthorized"}));
      }

      final userId = authPayload['userId'];
      final user = await userRepository.findById(userId.toString());

      if (user == null) {
        return Response.notFound(jsonEncode({"message": "User not found"}));
      }

      return Response.ok(
        jsonEncode({
          "success": true,
          "data": {
            "user_id": user['user_id'],
            "username": user['username'],
            "email": user['email'],
            "role_id": user['role_id'],
            "status": user['status'],
            "profile": user['user_profiles'], // Thông tin từ bảng user_profiles
          }
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({"message": e.toString()}));
    }
  }

  // Cập nhật thông tin Profile
  Future<Response> updateProfile(Request request) async {
    try {
      final authPayload = request.context['authPayload'] as Map<String, dynamic>?;
      if (authPayload == null) {
        return Response.forbidden(jsonEncode({"message": "Unauthorized"}));
      }

      final userId = int.parse(authPayload['userId'].toString());
      final body = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(body);

      // Danh sách các field được phép cập nhật trong user_profiles
      final allowedFields = ['full_name', 'name', 'gender', 'date_of_birth', 'phone_number', 'avatar_url'];
      final Map<String, dynamic> profileData = {};

      for (var field in allowedFields) {
        if (data.containsKey(field)) {
          profileData[field] = data[field];
        }
      }

      if (profileData.isEmpty) {
        return Response.badRequest(body: jsonEncode({"message": "Không có dữ liệu hợp lệ để cập nhật"}));
      }

      final updatedProfile = await userRepository.updateProfile(userId, profileData);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Cập nhật profile thành công",
          "data": updatedProfile
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({"message": e.toString()}));
    }
  }
}
