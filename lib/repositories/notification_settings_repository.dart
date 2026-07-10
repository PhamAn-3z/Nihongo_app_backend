import 'package:supabase/supabase.dart';

class NotificationSettingsRepository {
  final SupabaseClient supabase;

  NotificationSettingsRepository(this.supabase);

  // Get settings by user_id
  Future<Map<String, dynamic>?> getByUserId(int userId) async {
    final response = await supabase
        .from('notification_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return response;
  }

  // Create default settings for user
  Future<Map<String, dynamic>?> createDefaultSettings(int userId) async {
    final data = {
      'user_id': userId,
      'streak_reminder': 1,
      'streak_reminder_time': '20:00',
      'study_reminder': 1,
      'study_reminder_time': '19:00',
      'study_reminder_days': [1, 2, 3, 4, 5, 6, 7],
      'exp_notify': 1,
      'sub_expiry_notify': 1,
      'promo_notify': 1,
    };
    final response = await supabase
        .from('notification_settings')
        .insert(data)
        .select()
        .maybeSingle();
    return response;
  }

  // Update study reminder settings
  Future<Map<String, dynamic>?> updateStudyReminder(
      int userId, int isEnabled, String time, List<int> days) async {
    final response = await supabase
        .from('notification_settings')
        .update({
          'study_reminder': isEnabled,
          'study_reminder_time': time,
          'study_reminder_days': days,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .select()
        .maybeSingle();
    return response;
  }
}
