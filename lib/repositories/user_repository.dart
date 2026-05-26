import 'package:supabase/supabase.dart';

class UserRepository {
  final SupabaseClient supabase;

  UserRepository(this.supabase);

  // Tìm user theo email (tương tự findByEmail trong Spring Data JPA)
  Future<Map<String, dynamic>?> findByEmail(String email) async {
    final response = await supabase
        .from('users')
        .select()
        .eq('email', email)
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
