import 'package:shelf_router/shelf_router.dart';
import '../controllers/user_controller.dart';

Router userRoutes(UserController controller) {
  final router = Router();

  // API lấy thông tin Profile: GET /api/v1/user/profile
  router.get('/profile', controller.getProfile);

  // API cập nhật Profile: PUT /api/v1/user/update-profile
  router.put('/update-profile', controller.updateProfile);

  return router;
}
