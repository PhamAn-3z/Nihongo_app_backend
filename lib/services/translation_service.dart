import '../repositories/translation_repository.dart';
import 'gemini_service.dart';

class TranslationService {
  final TranslationRepository repository;
  final GeminiService geminiService;

  TranslationService(this.repository, this.geminiService);

  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    // 1. Check Cache
    final cached = await repository.getFromCache(
      sourceText: text,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );

    if (cached != null) {
      print('[Cache Hit] $sourceLang -> $targetLang: "$text"');
      return cached['translated_text'];
    }

    print('[Cache Miss] $sourceLang -> $targetLang: "$text"');

    // 2. Call Gemini
    final translatedText = await geminiService.translate(
      text: text,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );

    // 3. Save to Cache
    await repository.saveToCache(
      sourceText: text,
      translatedText: translatedText,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );

    return translatedText;
  }
}
