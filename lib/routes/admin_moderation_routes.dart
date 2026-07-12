import 'package:shelf_router/shelf_router.dart';
import '../controllers/admin_moderation_controller.dart';

Router adminModerationRoutes(AdminModerationController controller) {
  final router = Router();

  // Cảnh cáo người dùng
  router.post('/users/<id>/warning', controller.warnUser);

  // Ban tạm thời
  router.post('/users/<id>/temp-ban', controller.tempBanUser);

  // Ban vĩnh viễn
  router.post('/users/<id>/permanent-ban', controller.permanentBanUser);

  // Xem lịch sử xử phạt của một người dùng
  router.get('/users/<id>/penalties', controller.getPenaltyHistory);

  return router;
}
