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

  // Tìm user theo user_id
  Future<Map<String, dynamic>?> findById(String userId) async {
    final response = await supabase
        .from('users')
        .select()
        .eq('user_id', userId);

    return (response as List).isEmpty ? null : response.first;
  }

  // Tạo user mới
  Future<Map<String, dynamic>?> createUser(Map<String, dynamic> user) async {
    final response = await supabase
        .from('users')
        .insert(user)
        .select();
    return (response as List).isEmpty ? null : response.first;
  }
}
