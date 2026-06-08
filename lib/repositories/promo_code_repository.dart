import 'package:supabase/supabase.dart';

class PromoCodeRepository {
  final SupabaseClient supabase;

  PromoCodeRepository(this.supabase);

  Future<Map<String, dynamic>?> getPromoCodeByCode(String code) async {
    // Note: Assuming 'code' column might exist or using ID as fallback
    // The DBML didn't specify a 'code' string, but typically PromoCodes have them.
    return await supabase.from('PromoCode').select().eq('id', code).maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getActivePromoCodes() async {
    return await supabase.from('PromoCode').select().eq('Expired', false);
  }

  Future<List<Map<String, dynamic>>> getAllPromoCodes() async {
    return await supabase.from('PromoCode').select();
  }

  Future<Map<String, dynamic>?> getPromoCodeById(int id) async {
    return await supabase.from('PromoCode').select().eq('id', id).maybeSingle();
  }

  Future<Map<String, dynamic>> createPromoCode(Map<String, dynamic> data) async {
    return await supabase.from('PromoCode').insert(data).select().single();
  }

  Future<Map<String, dynamic>> updatePromoCode(int id, Map<String, dynamic> data) async {
    return await supabase
        .from('PromoCode')
        .update(data)
        .eq('id', id)
        .select()
        .single();
  }
}
