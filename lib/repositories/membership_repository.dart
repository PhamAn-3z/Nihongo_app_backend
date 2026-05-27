import 'package:supabase/supabase.dart';

class MembershipRepository {
  final SupabaseClient supabase;

  MembershipRepository(this.supabase);

  Future<List<Map<String, dynamic>>> getAllMemberships() async {
    return await supabase.from('Membership').select();
  }

  Future<Map<String, dynamic>?> getMembershipById(int id) async {
    return await supabase.from('Membership').select().eq('id', id).maybeSingle();
  }

  Future<Map<String, dynamic>> createMembership(Map<String, dynamic> data) async {
    return await supabase.from('Membership').insert(data).select().single();
  }

  Future<Map<String, dynamic>> updateMembership(int id, Map<String, dynamic> data) async {
    return await supabase
        .from('Membership')
        .update(data)
        .eq('id', id)
        .select()
        .single();
  }
}
