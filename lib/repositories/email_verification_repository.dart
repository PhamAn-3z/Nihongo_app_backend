import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

class EmailVerificationRepository {
  final SupabaseClient supabase;
  final _uuid = const Uuid();

  EmailVerificationRepository(this.supabase);

  Future<Map<String, dynamic>> createVerification({
    required int userId,
    required String otpCode,
    required DateTime expiresAt,
  }) async {
    final response = await supabase
        .from('email_verifications')
        .insert({
          'id': _uuid.v4(),
          'user_id': userId,
          'otp_code': otpCode,
          'expires_at': expiresAt.toIso8601String(),
          'verified': false,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return response;
  }

  Future<Map<String, dynamic>?> findLatestByUserId(int userId) async {
    final response = await supabase
        .from('email_verifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response;
  }

  Future<void> markAsVerified(dynamic id) async {
    await supabase
        .from('email_verifications')
        .update({'verified': true})
        .eq('id', id);
  }
}
