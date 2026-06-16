import 'package:supabase/supabase.dart';

class UserRepository {
  final SupabaseClient supabase;

  UserRepository(this.supabase);

  // Tìm user theo email
  Future<Map<String, dynamic>?> findByEmail(String email) async {
    final response = await supabase
        .from('users')
        .select()
        .eq('email', email)
        .maybeSingle();

    return response;
  }

  // Tìm user theo user_id (Lấy luôn thông tin từ bảng user_profiles nếu có)
  Future<Map<String, dynamic>?> findById(String userId) async {
    final response = await supabase
        .from('users')
        .select('*, user_profiles(*)')
        .eq('user_id', userId)
        .maybeSingle();

    return response;
  }

  // Tạo user mới
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> user) async {
    final response = await supabase
        .from('users')
        .insert(user)
        .select()
        .single();
    return response;
  }

  // Cập nhật hoặc tạo mới profile (Hỗ trợ cập nhật từng phần)
  Future<Map<String, dynamic>> updateProfile(String userId, Map<String, dynamic> profileData) async {
    // Kiểm tra xem đã có profile chưa
    final existing = await supabase
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      // Nếu chưa có thì insert mới
      return await supabase
          .from('user_profiles')
          .insert({
            'user_id': userId,
            ...profileData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
    } else {
      // Nếu đã có thì update (chỉ cập nhật các field được gửi lên, các field khác giữ nguyên)
      return await supabase
          .from('user_profiles')
          .update({
            ...profileData,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .select()
          .single();
    }
  }
}
