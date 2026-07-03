import 'package:supabase/supabase.dart';

class ReceiptRepository {
  final SupabaseClient supabase;

  ReceiptRepository(this.supabase);

  Future<List<Map<String, dynamic>>> getReceiptsByUserId(int userId) async {
    return await supabase.from('Receipt').select().eq('user_id', userId);
  }

  Future<Map<String, dynamic>?> getReceiptById(int id) async {
    final response = await supabase.from('Receipt').select().eq('id', id);
    return (response as List).isEmpty ? null : response.first;
  }

  Future<Map<String, dynamic>?> createReceipt(Map<String, dynamic> data) async {
    final response = await supabase.from('Receipt').insert(data).select();
    return (response as List).isEmpty ? null : response.first;
  }

  Future<Map<String, dynamic>?> updatePaymentStatus(int id, bool isPaid) async {
    final response = await supabase
        .from('Receipt')
        .update({'is_paid': isPaid})
        .eq('id', id)
        .select();
    return (response as List).isEmpty ? null : response.first;
  }

  Future<Map<String, dynamic>?> updateReceipt(int id, Map<String, dynamic> data) async {
    final response = await supabase
        .from('Receipt')
        .update(data)
        .eq('id', id)
        .select();
    return (response as List).isEmpty ? null : response.first;
  }

  Future<void> deleteExpiredUnpaidReceipts() async {
    final tenMinutesAgo = DateTime.now().subtract(Duration(minutes: 30)).toIso8601String();
    
    await supabase
        .from('Receipt')
        .delete()
        .eq('is_paid', false)
        .lt('dayCreated', tenMinutesAgo);
  }
}
