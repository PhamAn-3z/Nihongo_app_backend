import 'package:supabase/supabase.dart';

class TranslationRepository {
  final SupabaseClient supabase;

  TranslationRepository(this.supabase);

  /// Tìm kiếm chính xác bộ ba (source_text, source_lang, target_lang)
  Future<Map<String, dynamic>?> getFromCache({
    required String sourceText,
    required String sourceLang,
    required String targetLang,
  }) async {
    final response = await supabase
        .from('translations')
        .select()
        .eq('source_text', sourceText.trim())
        .eq('source_lang', sourceLang)
        .eq('target_lang', targetLang)
        .maybeSingle();
    return response;
  }

  Future<void> saveToCache({
    required String sourceText,
    required String translatedText,
    required String sourceLang,
    required String targetLang,
  }) async {
    try {
      await supabase.from('translations').upsert({
        'source_text': sourceText.trim(),
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'translated_text': translatedText.trim(),
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'source_text, source_lang, target_lang');
    } catch (e) {
      print('⚠️ [TranslationRepository] Lỗi lưu cache: $e');
    }
  }
}
