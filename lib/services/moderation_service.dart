import '../repositories/moderation_repository.dart';
import '../repositories/user_repository.dart';
import 'notification_service.dart';

class ModerationService {
  final ModerationRepository moderationRepository;
  final UserRepository userRepository;
  final NotificationService notificationService; // Thêm NotificationService

  ModerationService(this.moderationRepository, this.userRepository, this.notificationService);

  // 1. Cảnh cáo người dùng
  Future<void> warnUser({
    required int userId,
    required int adminId,
    required String reason,
  }) async {
    await moderationRepository.createPenalty({
      'user_id': userId,
      'admin_id': adminId,
      'penalty_type': 'warning',
      'reason': reason,
    });
    
    await userRepository.updateStatus(userId, 'warned');

    // Gửi thông báo
    await notificationService.createNotification({
      'user_id': userId,
      'type': 'warning',
      'title': 'Cảnh báo tài khoản',
      'body': 'Tài khoản của bạn vừa nhận một cảnh báo từ hệ thống. Lý do: $reason',
      'is_read': 0,
    });
  }

  // 2. Ban tạm thời
  Future<void> tempBan({
    required int userId,
    required int adminId,
    required String reason,
    required int days,
  }) async {
    final startDate = DateTime.now();
    final endDate = startDate.add(Duration(days: days));

    final activePenalty = await moderationRepository.getActivePenalty(userId);
    if (activePenalty != null) {
      await moderationRepository.deactivatePenalty(activePenalty['id']);
    }

    await moderationRepository.createPenalty({
      'user_id': userId,
      'admin_id': adminId,
      'penalty_type': 'temp_ban',
      'reason': reason,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': true,
    });

    await userRepository.updateStatus(userId, 'temporarily_banned');

    // Gửi thông báo (Dù bị ban không đăng nhập được nhưng user vẫn có thể thấy qua email hoặc sau khi unban)
    await notificationService.createNotification({
      'user_id': userId,
      'type': 'ban',
      'title': 'Tài khoản bị khóa tạm thời',
      'body': 'Tài khoản của bạn đã bị khóa trong $days ngày. Hết hạn vào: ${endDate.toLocal()}. Lý do: $reason',
      'is_read': 0,
    });
  }

  // 3. Ban vĩnh viễn
  Future<void> permanentBan({
    required int userId,
    required int adminId,
    required String reason,
  }) async {
    final activePenalty = await moderationRepository.getActivePenalty(userId);
    if (activePenalty != null) {
      await moderationRepository.deactivatePenalty(activePenalty['id']);
    }

    await moderationRepository.createPenalty({
      'user_id': userId,
      'admin_id': adminId,
      'penalty_type': 'perm_ban',
      'reason': reason,
      'is_active': true,
    });

    await userRepository.updateStatus(userId, 'permanently_banned');

    await notificationService.createNotification({
      'user_id': userId,
      'type': 'ban_permanent',
      'title': 'Tài khoản bị khóa vĩnh viễn',
      'body': 'Tài khoản của bạn đã bị khóa vĩnh viễn do vi phạm quy định cộng đồng. Lý do: $reason',
      'is_read': 0,
    });
  }

  // 4. Kiểm tra quyền truy cập (Dùng khi Login)
  Future<String?> checkUserAccess(int userId) async {
    final activePenalty = await moderationRepository.getActivePenalty(userId);
    
    if (activePenalty == null) return null;

    final type = activePenalty['penalty_type'];
    final reason = activePenalty['reason'];

    if (type == 'perm_ban') {
      return 'Tài khoản của bạn đã bị khóa vĩnh viễn. Lý do: $reason';
    }

    if (type == 'temp_ban') {
      final endDate = DateTime.parse(activePenalty['end_date']);
      if (endDate.isAfter(DateTime.now())) {
        return 'Tài khoản đang bị khóa tạm thời đến ${endDate.toLocal()}. Lý do: $reason';
      } else {
        await moderationRepository.deactivatePenalty(activePenalty['id']);
        await userRepository.updateStatus(userId, 'active');
        return null;
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> getPenaltyHistory(int userId) async {
    return await moderationRepository.getHistoryByUserId(userId);
  }
}
