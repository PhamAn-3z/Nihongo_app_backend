import 'package:supabase/supabase.dart';

class ModerationRepository {
  final SupabaseClient supabase;

  ModerationRepository(this.supabase);

  // Lưu một án phạt mới
  Future<Map<String, dynamic>> createPenalty(Map<String, dynamic> data) async {
    final response = await supabase
        .from('user_penalties')
        .insert(data)
        .select()
        .single();
    return response;
  }

  // Lấy án phạt đang có hiệu lực của user
  Future<Map<String, dynamic>?> getActivePenalty(int userId) async {
    final response = await supabase
        .from('user_penalties')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .maybeSingle();
    return response;
  }

  // Lấy toàn bộ lịch sử xử phạt của user
  Future<List<Map<String, dynamic>>> getHistoryByUserId(int userId) async {
    final response = await supabase
        .from('user_penalties')
        .select('*, admin:admin_id(username)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Deactivate án phạt (dùng khi hết hạn ban hoặc bị ghi đè)
  Future<void> deactivatePenalty(int penaltyId) async {
    await supabase
        .from('user_penalties')
        .update({'is_active': false})
        .eq('id', penaltyId);
  }
}
