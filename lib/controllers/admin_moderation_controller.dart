import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/moderation_service.dart';
import '../repositories/user_repository.dart';

class AdminModerationController {
  final ModerationService moderationService;
  final UserRepository userRepository;

  AdminModerationController(this.moderationService, this.userRepository);

  /// Kiểm tra quyền Admin trực tiếp từ Token Payload
  bool _isAdmin(Request request) {
    final authPayload = request.context['authPayload'] as Map<String, dynamic>?;
    if (authPayload == null) return false;

    // Lấy roleId từ token (đảm bảo key 'roleId' khớp với JwtService)
    final roleId = authPayload['roleId'];
    
    // Log để debug - Bạn hãy quan sát terminal khi gọi API
    print('DEBUG: Checking permissions for UserID: ${authPayload['userId']} - RoleID in token: $roleId');

    // So sánh: role_id = 3 là Admin. Ép kiểu về String để so sánh an toàn nhất.
    return roleId != null && roleId.toString() == '3';
  }

  // GET /admin/users
  Future<Response> getAllUsers(Request request) async {
    try {
      if (!_isAdmin(request)) {
        return Response.forbidden(
          jsonEncode({
            'success': false, 
            'message': 'Quyền truy cập bị từ chối: Yêu cầu quyền Admin (role_id=3)'
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      final users = await userRepository.getAllUsers();
      
      return Response.ok(
        jsonEncode({
          "success": true,
          "data": users
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': e.toString()}));
    }
  }

  // POST /admin/users/:id/warning
  Future<Response> warnUser(Request request, String id) async {
    try {
      if (!_isAdmin(request)) return Response.forbidden(jsonEncode({'message': 'Quyền truy cập bị từ chối'}));

      final data = jsonDecode(await request.readAsString());
      final reason = data['reason'];
      if (reason == null) return Response.badRequest(body: jsonEncode({'message': 'Lý do là bắt buộc'}));

      final authPayload = request.context['authPayload'] as Map<String, dynamic>;
      final adminId = int.parse(authPayload['userId'].toString());

      await moderationService.warnUser(
        userId: int.parse(id),
        adminId: adminId,
        reason: reason,
      );

      return Response.ok(jsonEncode({'message': 'Đã gửi cảnh cáo thành công'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': e.toString()}));
    }
  }

  // POST /admin/users/:id/temp-ban
  Future<Response> tempBanUser(Request request, String id) async {
    try {
      if (!_isAdmin(request)) return Response.forbidden(jsonEncode({'message': 'Quyền truy cập bị từ chối'}));

      final data = jsonDecode(await request.readAsString());
      final reason = data['reason'];
      final days = data['days'];

      if (reason == null || days == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Lý do và số ngày ban là bắt buộc'}));
      }

      final authPayload = request.context['authPayload'] as Map<String, dynamic>;
      final adminId = int.parse(authPayload['userId'].toString());

      await moderationService.tempBan(
        userId: int.parse(id),
        adminId: adminId,
        reason: reason,
        days: int.parse(days.toString()),
      );

      return Response.ok(jsonEncode({'message': 'Đã ban tạm thời người dùng $days ngày'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': e.toString()}));
    }
  }

  // POST /admin/users/:id/permanent-ban
  Future<Response> permanentBanUser(Request request, String id) async {
    try {
      if (!_isAdmin(request)) return Response.forbidden(jsonEncode({'message': 'Quyền truy cập bị từ chối'}));

      final data = jsonDecode(await request.readAsString());
      final reason = data['reason'];
      if (reason == null) return Response.badRequest(body: jsonEncode({'message': 'Lý do là bắt buộc'}));

      final authPayload = request.context['authPayload'] as Map<String, dynamic>;
      final adminId = int.parse(authPayload['userId'].toString());

      await moderationService.permanentBan(
        userId: int.parse(id),
        adminId: adminId,
        reason: reason,
      );

      return Response.ok(jsonEncode({'message': 'Đã khóa tài khoản vĩnh viễn'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': e.toString()}));
    }
  }

  // GET /admin/users/:id/penalties
  Future<Response> getPenaltyHistory(Request request, String id) async {
    try {
      if (!_isAdmin(request)) return Response.forbidden(jsonEncode({'message': 'Quyền truy cập bị từ chối'}));

      final history = await moderationService.getPenaltyHistory(int.parse(id));
      return Response.ok(jsonEncode(history), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': e.toString()}));
    }
  }
}
