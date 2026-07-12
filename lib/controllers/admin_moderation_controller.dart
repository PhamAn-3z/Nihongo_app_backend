import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/moderation_service.dart';
import '../repositories/user_repository.dart';

class AdminModerationController {
  final ModerationService moderationService;
  final UserRepository userRepository;

  AdminModerationController(this.moderationService, this.userRepository);

  // Helper để kiểm tra quyền Admin
  Future<bool> _isAdmin(Request request) async {
    final authPayload = request.context['authPayload'] as Map<String, dynamic>?;
    if (authPayload == null) return false;

    final adminId = authPayload['userId'];
    final user = await userRepository.findById(adminId.toString());
    
    // role_id = 3 là Admin
    return user != null && user['role_id'] == 3;
  }

  // POST /admin/users/:id/warning
  Future<Response> warnUser(Request request, String id) async {
    try {
      if (!await _isAdmin(request)) return Response.forbidden(jsonEncode({'message': 'Quyền truy cập bị từ chối'}));

      final data = jsonDecode(await request.readAsString());
      final reason = data['reason'];
      if (reason == null) return Response.badRequest(body: jsonEncode({'message': 'Lý do là bắt buộc'}));

      final authPayload = request.context['authPayload'] as Map<String, dynamic>;
      final adminId = int.parse(authPayload['userId']);

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
      if (!await _isAdmin(request)) return Response.forbidden(jsonEncode({'message': 'Quyền truy cập bị từ chối'}));

      final data = jsonDecode(await request.readAsString());
      final reason = data['reason'];
      final days = data['days'];

      if (reason == null || days == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Lý do và số ngày ban là bắt buộc'}));
      }

      final authPayload = request.context['authPayload'] as Map<String, dynamic>;
      final adminId = int.parse(authPayload['userId']);

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
      if (!await _isAdmin(request)) return Response.forbidden(jsonEncode({'message': 'Quyền truy cập bị từ chối'}));

      final data = jsonDecode(await request.readAsString());
      final reason = data['reason'];
      if (reason == null) return Response.badRequest(body: jsonEncode({'message': 'Lý do là bắt buộc'}));

      final authPayload = request.context['authPayload'] as Map<String, dynamic>;
      final adminId = int.parse(authPayload['userId']);

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
      if (!await _isAdmin(request)) return Response.forbidden(jsonEncode({'message': 'Quyền truy cập bị từ chối'}));

      final history = await moderationService.getPenaltyHistory(int.parse(id));
      return Response.ok(jsonEncode(history), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': e.toString()}));
    }
  }
}
