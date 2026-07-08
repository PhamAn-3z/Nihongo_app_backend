import '../repositories/study_log_repository.dart';

class StudyLogService {
  final StudyLogRepository _repository;

  StudyLogService(this._repository);

  /// Xử lý nghiệp vụ khi kết thúc một phiên học tập (Tích hợp SM-2 và Transaction)
  Future<Map<String, dynamic>> processSessionEnd({
    required dynamic userId,
    required Map<String, dynamic> body,
  }) async {
    // Chuẩn hóa kiểu dữ liệu userId (int)
    final int fUserId = userId is String ? int.parse(userId) : userId as int;

    // Gọi repository để thực thi Postgres Function (Transaction)
    final result = await _repository.processFullStudySession(
      userId: fUserId,
      deckId: body['deck_id'],
      cardsLearned: body['cards_learned'] ?? 0,
      cardsReviewed: body['cards_reviewed'] ?? 0,
      durationSeconds: body['duration_seconds'] ?? 0,
      cardRatings: body['card_ratings'] ?? [], // Danh sách rating từng thẻ
    );

    return result;
  }
}
