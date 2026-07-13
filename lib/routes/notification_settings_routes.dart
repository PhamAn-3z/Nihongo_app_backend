import 'package:shelf_router/shelf_router.dart';
import '../controllers/notification_settings_controller.dart';

Router notificationSettingsRoutes(NotificationSettingsController controller) {
  final router = Router();

  router.get('/', controller.getSettings);
  router.put('/study-reminder', controller.updateStudyReminder);

  return router;
}
