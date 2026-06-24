import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/notification_service.dart';

class NotificationController {
  final NotificationService notificationService;

  NotificationController(this.notificationService);

  // Helper to extract authenticated user ID
  int? _getAuthenticatedUserId(Request request) {
    final authPayload = request.context['authPayload'] as Map<String, dynamic>?;
    if (authPayload == null) return null;
    final userIdRaw = authPayload['userId'];
    if (userIdRaw == null) return null;
    return int.tryParse(userIdRaw.toString());
  }

  // Get notifications for current logged-in user
  Future<Response> getNotifications(Request request) async {
    try {
      final userId = _getAuthenticatedUserId(request);
      if (userId == null) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Không tìm thấy thông tin xác thực hoặc Token không hợp lệ.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final notifications = await notificationService.getNotificationsForUser(userId);
      return Response.ok(
        jsonEncode({'status': 'success', 'data': notifications}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Get notifications by user ID (route parameter)
  Future<Response> getNotificationsByUserId(Request request, String userId) async {
    try {
      final parsedUserId = int.tryParse(userId);
      if (parsedUserId == null) {
        return Response.badRequest(
          body: jsonEncode({'status': 'error', 'message': 'Invalid user ID format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final notifications = await notificationService.getNotificationsForUser(parsedUserId);
      return Response.ok(
        jsonEncode({'status': 'success', 'data': notifications}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Create a notification
  Future<Response> create(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final newNotification = await notificationService.createNotification(data);
      return Response.ok(
        jsonEncode({'status': 'success', 'data': newNotification}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Mark notification as read
  Future<Response> markAsRead(Request request, String id) async {
    try {
      final notificationId = int.tryParse(id);
      if (notificationId == null) {
        return Response.badRequest(
          body: jsonEncode({'status': 'error', 'message': 'Invalid notification ID format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final updatedNotification = await notificationService.markAsRead(notificationId);
      return Response.ok(
        jsonEncode({'status': 'success', 'data': updatedNotification}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Mark all notifications for authenticated user as read
  Future<Response> markAllAsRead(Request request) async {
    try {
      final userId = _getAuthenticatedUserId(request);
      if (userId == null) {
        return Response.forbidden(
          jsonEncode({'success': false, 'message': 'Không tìm thấy thông tin xác thực.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final updatedNotifications = await notificationService.markAllAsRead(userId);
      return Response.ok(
        jsonEncode({'status': 'success', 'data': updatedNotifications}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Delete notification
  Future<Response> delete(Request request, String id) async {
    try {
      final notificationId = int.tryParse(id);
      if (notificationId == null) {
        return Response.badRequest(
          body: jsonEncode({'status': 'error', 'message': 'Invalid notification ID format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await notificationService.deleteNotification(notificationId);
      return Response.ok(
        jsonEncode({'status': 'success', 'message': 'Notification deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
