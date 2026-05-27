import 'package:supabase/supabase.dart';

class UserStatsRepository {
  final SupabaseClient supabase;

  UserStatsRepository(this.supabase);

  Future<Map<String, dynamic>?> getUserStats(int userId) async {
    return await supabase.from('user_stats').select().eq('user_id', userId).maybeSingle();
  }

  Future<Map<String, dynamic>> createUserStats(Map<String, dynamic> data) async {
    return await supabase.from('user_stats').insert(data).select().single();
  }

  Future<Map<String, dynamic>> updateStats(int userId, Map<String, dynamic> updates) async {
    return await supabase
        .from('user_stats')
        .update(updates)
        .eq('user_id', userId)
        .select()
        .single();
  }
}
