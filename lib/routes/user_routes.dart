import 'package:shelf_router/shelf_router.dart';
import '../controllers/user_controller.dart';

Router userRoutes(UserController controller) {
  final router = Router();

  // API lấy thông tin Profile: GET /profile
  router.get('/profile', controller.getProfile);

  // API cập nhật thông tin Profile: PUT /profile
  router.put('/profile', controller.updateProfile);

  return router;
}
