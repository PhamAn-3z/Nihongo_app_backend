import '../repositories/user_stats_repository.dart';

class UserStatsService {
  final UserStatsRepository userStatsRepository;

  UserStatsService(this.userStatsRepository);

  Future<Map<String, dynamic>?> getStats(int userId) async {
    return await userStatsRepository.getUserStats(userId);
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
