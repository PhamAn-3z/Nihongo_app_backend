import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/notification_settings_service.dart';

class NotificationSettingsController {
  final NotificationSettingsService service;

  NotificationSettingsController(this.service);

  int? _getAuthenticatedUserId(Request request) {
    final authPayload = request.context['authPayload'] as Map<String, dynamic>?;
    if (authPayload == null) return null;
    final userIdRaw = authPayload['userId'];
    if (userIdRaw == null) return null;
    return int.tryParse(userIdRaw.toString());
  }

  Future<Response> getSettings(Request request) async {
    try {
      final userId = _getAuthenticatedUserId(request);
      if (userId == null) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Không tìm thấy thông tin xác thực.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final settings = await service.getSettingsForUser(userId);
      return Response.ok(
        jsonEncode({'status': 'success', 'data': settings}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> updateStudyReminder(Request request) async {
    try {
      final userId = _getAuthenticatedUserId(request);
      if (userId == null) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Không tìm thấy thông tin xác thực.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = await request.readAsString();
      final data = jsonDecode(body);

      final isEnabledRaw = data['is_enabled'];
      final time = data['time']?.toString();
      final daysRaw = data['days'] as List<dynamic>?;

      if (isEnabledRaw == null || time == null || daysRaw == null) {
        return Response.badRequest(
          body: jsonEncode({'status': 'error', 'message': 'Thiếu trường dữ liệu (is_enabled, time, days)'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      int isEnabled = 0;
      if (isEnabledRaw is bool) {
        isEnabled = isEnabledRaw ? 1 : 0;
      } else if (isEnabledRaw is int) {
        isEnabled = isEnabledRaw;
      } else {
        isEnabled = int.tryParse(isEnabledRaw.toString()) ?? 0;
      }

      List<int> days = daysRaw.map((e) => int.parse(e.toString())).toList();

      final updated = await service.updateStudyReminder(userId, isEnabled, time, days);
      
      return Response.ok(
        jsonEncode({'status': 'success', 'data': updated, 'message': 'Cập nhật thành công'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
