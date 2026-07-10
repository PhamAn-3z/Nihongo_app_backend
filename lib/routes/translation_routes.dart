import 'package:shelf_router/shelf_router.dart';
import '../controllers/translation_controller.dart';

Router translationRoutes(TranslationController controller) {
  final router = Router();

  // API Dịch thuật: POST /api/v1/translate
  router.post('/', controller.translate);

  return router;
}
