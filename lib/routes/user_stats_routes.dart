import 'package:shelf_router/shelf_router.dart';
import '../controllers/user_stats_controller.dart';

Router userStatsRoutes(UserStatsController controller) {
  final router = Router();
  router.get('/<userId>', controller.get);
  router.put('/<userId>', controller.update);
  return router;
}
