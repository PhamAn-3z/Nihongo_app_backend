import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey;
  final String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

  static const Map<String, String> languageNames = {
    'ja': 'Japanese',
    'vi': 'Vietnamese'
  };

  GeminiService(this.apiKey);

  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final url = Uri.parse('$_baseUrl?key=$apiKey');
    
    final sourceName = languageNames[sourceLang] ?? sourceLang;
    final targetName = languageNames[targetLang] ?? targetLang;

    final prompt = """
You are a professional translation engine.

Translate the following text from $sourceName to $targetName.

Rules:
- Return only the translated text.
- Do not explain.
- Do not add notes.
- Do not add quotation marks.
- Preserve original meaning and tone.

Text:
$text
""";

    print('[Gemini Request] $sourceLang -> $targetLang: "$text"');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 1024,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        final translatedText = data['candidates'][0]['content']['parts'][0]['text'];
        final result = translatedText.trim();
        print('[Gemini Success]');
        return result;
      } else {
        print('[Gemini Error] No candidates returned');
        throw Exception('Gemini API returned no candidates.');
      }
    } else if (response.statusCode == 503) {
      print('[Gemini Error] 503 - High Demand');
      throw Exception('Hệ thống đang quá tải - xin hãy thử lại sau giây lát.');
    } else {
      print('[Gemini Error] Status: ${response.statusCode}, Body: ${response.body}');
      throw Exception('Gemini API Error: ${response.body}');
    }
  }
}
