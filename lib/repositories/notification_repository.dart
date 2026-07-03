import 'package:supabase/supabase.dart';

class NotificationRepository {
  final SupabaseClient supabase;

  NotificationRepository(this.supabase);

  // Fetch notifications for a user, sorted by created_at descending
  Future<List<Map<String, dynamic>>> getByUserId(int userId) async {
    final response = await supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Create a new notification
  Future<Map<String, dynamic>?> createNotification(Map<String, dynamic> data) async {
    final response = await supabase
        .from('notifications')
        .insert(data)
        .select()
        .maybeSingle();
    return response;
  }

  // Mark a notification as read (is_read = 1)
  Future<Map<String, dynamic>?> markAsRead(int notificationId) async {
    final response = await supabase
        .from('notifications')
        .update({'is_read': 1})
        .eq('id', notificationId)
        .select()
        .maybeSingle();
    return response;
  }

  // Mark all notifications as read (is_read = 1) for a user
  Future<List<Map<String, dynamic>>> markAllAsRead(int userId) async {
    final response = await supabase
        .from('notifications')
        .update({'is_read': 1})
        .eq('user_id', userId)
        .select();
    return List<Map<String, dynamic>>.from(response);
  }

  // Delete a notification
  Future<void> deleteNotification(int notificationId) async {
    await supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }
}
