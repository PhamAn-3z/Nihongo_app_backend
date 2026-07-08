import 'package:supabase/supabase.dart';

class StudyLogRepository {
  final SupabaseClient _client;

  StudyLogRepository(this._client);

  /// Bước 1: Ghi nhật ký học tập vào bảng flashcard_study_logs
  Future<void> insertStudyLog({
    required int userId,
    required int deckId,
    required int cardsLearned,
    required int cardsReviewed,
    required int durationSeconds,
  }) async {
    await _client.from('flashcard_study_logs').insert({
      'user_id': userId,
      'deck_id': deckId,
      'cards_learned': cardsLearned,
      'cards_reviewed': cardsReviewed,
      'duration_seconds': durationSeconds,
      'studied_at': DateTime.now().toIso8601String(),
    });
  }

  /// Bước 2: Cập nhật thời gian vào học gần nhất của User đối với Deck này trong bảng user_decks
  Future<void> updateLastStudiedAt(int userId, int deckId) async {
    await _client
        .from('user_decks')
        .update({'last_studied_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .eq('deck_id', deckId);
  }

  /// Xử lý toàn bộ phiên học thông qua Postgres Function (RPC) để đảm bảo Transaction
  Future<Map<String, dynamic>> processFullStudySession({
    required int userId,
    required int deckId,
    required int cardsLearned,
    required int cardsReviewed,
    required int durationSeconds,
    required List<dynamic> cardRatings,
  }) async {
    final response = await _client.rpc('process_study_session', params: {
      'p_user_id': userId,
      'p_deck_id': deckId,
      'p_cards_learned': cardsLearned,
      'p_cards_reviewed': cardsReviewed,
      'p_duration_seconds': durationSeconds,
      'p_card_ratings': cardRatings,
    });

    return Map<String, dynamic>.from(response);
  }
}
