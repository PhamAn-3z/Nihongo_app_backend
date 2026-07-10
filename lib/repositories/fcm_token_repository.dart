import 'package:supabase/supabase.dart';

class FcmTokenRepository {
  final SupabaseClient supabase;

  FcmTokenRepository(this.supabase);

  // Lưu hoặc cập nhật FCM Token cho một user
  Future<void> saveToken(int userId, String token, String? deviceType) async {
    await supabase.from('fcm_tokens').upsert({
      'user_id': userId,
      'token': token,
      'device_type': deviceType,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'token');
  }

  // Xóa FCM Token (ví dụ khi logout)
  Future<void> deleteToken(String token) async {
    await supabase.from('fcm_tokens').delete().eq('token', token);
  }

  // Lấy danh sách token của một user
  Future<List<String>> getTokensByUserId(int userId) async {
    final response = await supabase
        .from('fcm_tokens')
        .select('token')
        .eq('user_id', userId);

    return (response as List).map((row) => row['token'] as String).toList();
  }
}
