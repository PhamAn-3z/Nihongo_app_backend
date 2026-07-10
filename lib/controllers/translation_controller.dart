import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/translation_service.dart';

class TranslationController {
  final TranslationService translationService;

  TranslationController(this.translationService);

  Future<Response> translate(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      
      final text = data['text'];
      final sourceLang = data['source_lang'];
      final targetLang = data['target_lang'];

      // 1. Validation
      if (text == null || text.toString().trim().isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'message': 'text is required and cannot be empty'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (sourceLang == null || targetLang == null) {
        return Response.badRequest(
          body: jsonEncode({'message': 'source_lang and target_lang are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (sourceLang == targetLang) {
        return Response.badRequest(
          body: jsonEncode({'message': 'source_lang and target_lang must be different'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Supported languages mapping
      const supportedLangs = ['ja', 'vi'];
      if (!supportedLangs.contains(sourceLang) || !supportedLangs.contains(targetLang)) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Supported languages are: ja, vi'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 2. Execute Translation
      final result = await translationService.translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );

      return Response.ok(
        jsonEncode({
          'source_text': text,
          'source_lang': sourceLang,
          'target_lang': targetLang,
          'translated_text': result,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      print('Translation Error: $e');
      print(stackTrace);

      return Response.internalServerError(
        body: jsonEncode({
          'message': e.toString().replaceAll('Exception: ', ''),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
