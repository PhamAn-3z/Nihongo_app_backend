import '../repositories/notification_repository.dart';
import '../repositories/fcm_token_repository.dart';
import 'fcm_service.dart';

class NotificationService {
  final NotificationRepository notificationRepository;
  final FcmTokenRepository fcmTokenRepository;
  final FcmService fcmService;

  NotificationService(this.notificationRepository, this.fcmTokenRepository, this.fcmService);

  Future<List<Map<String, dynamic>>> getNotificationsForUser(int userId) async {
    return await notificationRepository.getByUserId(userId);
  }

  Future<Map<String, dynamic>?> createNotification(Map<String, dynamic> data) async {
    // Validate required fields
    if (data['user_id'] == null) {
      throw ArgumentError('user_id is required');
    }
    if (data['type'] == null || (data['type'] as String).isEmpty) {
      throw ArgumentError('type is required');
    }
    if (data['title'] == null || (data['title'] as String).isEmpty) {
      throw ArgumentError('title is required');
    }
    if (data['body'] == null || (data['body'] as String).isEmpty) {
      throw ArgumentError('body is required');
    }

    // Process is_read value (convert boolean to integer if provided)
    if (data.containsKey('is_read')) {
      final isReadVal = data['is_read'];
      if (isReadVal is bool) {
        data['is_read'] = isReadVal ? 1 : 0;
      } else if (isReadVal is int) {
        data['is_read'] = isReadVal;
      } else {
        data['is_read'] = int.tryParse(isReadVal.toString()) ?? 0;
      }
    } else {
      data['is_read'] = 0;
    }

    // Default created_at if not present
    if (!data.containsKey('created_at')) {
      data['created_at'] = DateTime.now().toIso8601String();
    }

    final result = await notificationRepository.createNotification(data);

    if (result != null) {
      // Gửi Push Notification sau khi lưu vào DB thành công
      try {
        final userId = int.tryParse(data['user_id'].toString());
        if (userId != null) {
          final tokens = await fcmTokenRepository.getTokensByUserId(userId);
          if (tokens.isNotEmpty) {
            await fcmService.sendPushNotification(
              tokens: tokens,
              title: data['title'],
              body: data['body'],
              data: {
                'type': data['type'],
                if (data['action_url'] != null) 'action_url': data['action_url'],
              },
            );
          }
        }
      } catch (e) {
        print('⚠️ Lỗi khi gửi FCM trong NotificationService: $e');
      }
    }

    return result;
  }

  Future<Map<String, dynamic>?> markAsRead(int notificationId) async {
    return await notificationRepository.markAsRead(notificationId);
  }

  Future<List<Map<String, dynamic>>> markAllAsRead(int userId) async {
    return await notificationRepository.markAllAsRead(userId);
  }

  Future<void> deleteNotification(int notificationId) async {
    await notificationRepository.deleteNotification(notificationId);
  }
}
