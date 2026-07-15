import '../repositories/user_stats_repository.dart';

class UserStatsService {
  final UserStatsRepository userStatsRepository;

  UserStatsService(this.userStatsRepository);

  Future<Map<String, dynamic>?> getStats(int userId) async {
    return await userStatsRepository.getUserStats(userId);
  }

  /// Kiểm tra và tự động thu hồi nếu gói Membership đã hết hạn
  Future<void> checkAndRevokeIfExpired(int userId) async {
    final stats = await userStatsRepository.getUserStats(userId);
    if (stats == null) return;

    final int membershipId = stats['membership_id'] ?? 1;
    final String? expiredDateStr = stats['membership_expired_date'];

    // Nếu không phải gói Free (ID=1) và có ngày hết hạn
    if (membershipId != 1 && expiredDateStr != null) {
      final expiredDate = DateTime.parse(expiredDateStr);
      if (expiredDate.isBefore(DateTime.now())) {
        print('🔔 User $userId đã hết hạn gói Pro. Tự động chuyển về gói Free.');
        await userStatsRepository.updateStats(userId, {
          'membership_id': 1,
          'membership_expired_date': null,
        });
      }
    }
  }

  Future<Map<String, dynamic>?> updateStats(int userId, Map<String, dynamic> updates) async {
    // Prevent updating user_id
    updates.remove('user_id');
    
    // Handle isActive/is_active mapping to ensure consistency
    if (updates.containsKey('isActive')) {
      updates['is_active'] = updates['isActive'];
      updates.remove('isActive');
    }
    
    return await userStatsRepository.updateStats(userId, updates);
  }

  Future<Map<String, dynamic>?> initializeStats(int userId) async {
    return await userStatsRepository.createUserStats({
      'user_id': userId,
      'current_streak': 0,
      'max_streak': 0,
      'total_exp': 0,
      'membership_id': 1,
      'is_active': true,
      'last_study_date': null,
      'membership_expired_date': null,
    });
  }
}
