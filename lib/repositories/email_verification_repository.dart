import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

class EmailVerificationRepository {
  final SupabaseClient supabase;

  EmailVerificationRepository(this.supabase);

  Future<void> createVerification({
    required int userId,
    required String otpCode,
    required DateTime expiresAt,
  }) async {
    await supabase.from('email_verifications').insert({
      'id': const Uuid().v4(),
      'user_id': userId,
      'otp_code': otpCode,
      'expires_at': expiresAt.toIso8601String(),
      'verified': false,
    });
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

  Future<void> markAsVerified(String id) async {
    await supabase
        .from('email_verifications')
        .update({'verified': true})
        .eq('id', id);
  }
}
