import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../repositories/user_repository.dart';
import '../services/user_stats_service.dart';

class UserController {
  final UserRepository userRepository;
  final UserStatsService userStatsService;

  UserController(this.userRepository, this.userStatsService);

  // Lấy thông tin Profile
  Future<Response> getProfile(Request request) async {
    try {
      final authPayload = request.context['authPayload'] as Map<String, dynamic>?;
      if (authPayload == null) {
        return Response.forbidden(jsonEncode({"message": "Unauthorized"}));
      }

      final userId = int.parse(authPayload['userId'].toString());

      // Kiểm tra và thu hồi Membership nếu hết hạn ngay khi user truy cập Profile
      await userStatsService.checkAndRevokeIfExpired(userId);

      final user = await userRepository.findById(userId.toString());

      if (user == null) {
        return Response.notFound(jsonEncode({"message": "User not found"}));
      }

      // Lấy thông tin stats và membership
      final statsData = user['user_stats'];
      final stats = (statsData is List && statsData.isNotEmpty) ? statsData[0] : statsData;

      // Lấy thông tin profile
      final profileData = user['user_profiles'];
      final profile = (profileData is List && profileData.isNotEmpty) ? profileData[0] : (profileData ?? {});

      // Lấy rank từ Membership lồng bên trong stats
      String membershipRank = "None";
      if (stats != null && stats['Membership'] != null) {
        final membership = (stats['Membership'] is List) ? stats['Membership'][0] : stats['Membership'];
        membershipRank = membership['membershipRank'] ?? "None";
      }

      final bool isPremium = membershipRank != "None" && membershipRank != "N/A";

      return Response.ok(
        jsonEncode({
          "success": true,
          "data": {
            "user_id": user['user_id'],
            "username": user['username'],
            "email": user['email'],
            "role_id": user['role_id'],
            "is_premium": isPremium,
            "membership_rank": membershipRank,
            // Làm phẳng Profile
            "full_name": profile['full_name'],
            "avatar_url": profile['avatar_url'],
            "phone_number": profile['phone_number'],
            "gender": profile['gender'],
            "date_of_birth": profile['date_of_birth'],
            // Làm gọn Stats
            "stats": {
              "total_exp": stats?['total_exp'] ?? 0,
              "current_streak": stats?['current_streak'] ?? 0,
              "max_streak": stats?['max_streak'] ?? 0,
              "level": ((stats?['total_exp'] ?? 0) ~/ 100) + 1,
              "last_study_date": stats?['last_study_date'],
              "membership_expired_date": stats?['membership_expired_date'],
            }
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
