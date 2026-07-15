import 'package:supabase/supabase.dart';

class UserRepository {
  final SupabaseClient supabase;

  UserRepository(this.supabase);

  // Tìm user theo email
  Future<Map<String, dynamic>?> findByEmail(String email) async {
    final response = await supabase
        .from('users')
        .select()
        .eq('email', email);

    return (response as List).isEmpty ? null : response.first;
  }

  // Tìm user theo username
  Future<Map<String, dynamic>?> findByUsername(String username) async {
    final response = await supabase
        .from('users')
        .select()
        .eq('username', username);

    return (response as List).isEmpty ? null : response.first;
  }

  // Tìm user theo user_id (Bao gồm cả thông tin profile, stats và hạng thành viên)
  Future<Map<String, dynamic>?> findById(String userId) async {
    final response = await supabase
        .from('users')
        .select('*, user_profiles(*), user_stats(*, Membership(*))')
        .eq('user_id', userId)
        .maybeSingle();

    return response;
  }

  // Tạo user mới
  Future<Map<String, dynamic>?> createUser(Map<String, dynamic> user) async {
    final response = await supabase
        .from('users')
        .insert(user)
        .select();
    return (response as List).isEmpty ? null : response.first;
  }

  // Cập nhật profile (full_name, gender, phone_number, avatar_url, etc.)
  Future<Map<String, dynamic>> updateProfile(int userId, Map<String, dynamic> profileData) async {
    final response = await supabase
        .from('user_profiles')
        .upsert({
          'user_id': userId,
          ...profileData,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return response;
  }

  // Cập nhật trạng thái xác thực email
  Future<void> markEmailAsVerified(int userId) async {
    await supabase
        .from('users')
        .update({'email_verified': true})
        .eq('user_id', userId);
  }

  // Cập nhật trạng thái (active, warned, temporarily_banned, permanently_banned)
  Future<void> updateStatus(int userId, String status) async {
    await supabase
        .from('users')
        .update({'status': status})
        .eq('user_id', userId);
  }
}
