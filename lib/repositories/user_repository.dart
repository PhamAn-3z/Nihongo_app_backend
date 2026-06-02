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

  // Tìm user theo user_id
  Future<Map<String, dynamic>?> findById(String userId) async {
    final response = await supabase
        .from('users')
        .select()
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
}
