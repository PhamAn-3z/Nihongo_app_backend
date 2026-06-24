import 'package:shelf_router/shelf_router.dart';
import '../controllers/notification_controller.dart';

Router notificationRoutes(NotificationController controller) {
  final router = Router();

  router.get('/', controller.getNotifications);
  router.get('/user/<userId>', controller.getNotificationsByUserId);
  router.post('/', controller.create);
  router.put('/<id>/read', controller.markAsRead);
  router.put('/read-all', controller.markAllAsRead);
  router.delete('/<id>', controller.delete);

  return router;
}
