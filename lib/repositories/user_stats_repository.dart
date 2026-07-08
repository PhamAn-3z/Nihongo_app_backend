import 'package:supabase/supabase.dart';

class UserStatsRepository {
  final SupabaseClient supabase;

  UserStatsRepository(this.supabase);

  Future<Map<String, dynamic>?> getUserStats(int userId) async {
    final response = await supabase.from('user_stats').select().eq('user_id', userId);
    return (response as List).isEmpty ? null : response.first;
  }

  Future<Map<String, dynamic>?> createUserStats(Map<String, dynamic> data) async {
    final response = await supabase.from('user_stats').insert(data).select();
    return (response as List).isEmpty ? null : response.first;
  }

  Future<Map<String, dynamic>?> updateStats(int userId, Map<String, dynamic> updates) async {
    final response = await supabase
        .from('user_stats')
        .update(updates)
        .eq('user_id', userId)
        .select();
    return (response as List).isEmpty ? null : response.first;
  }

  Future<Map<String, dynamic>?> getUserStatsWithMembership(int userId) async {
    final response = await supabase
        .from('user_stats')
        .select('*, Membership(*)')
        .eq('user_id', userId);

    return (response as List).isEmpty ? null : response.first;
  }
}
