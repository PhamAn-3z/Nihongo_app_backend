import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../controllers/study_log_controller.dart';

Router studyLogRoutes(StudyLogController controller) {
  final router = Router();

  /// Ghi nhận kết quả sau khi kết thúc một phiên học tập Flashcard
  /// POST /api/v1/study-logs/session-end
  router.post('/session-end', controller.handleSessionEnd);

  return router;
}
