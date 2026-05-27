import 'package:shelf_router/shelf_router.dart';
import '../controllers/membership_controller.dart';

Router membershipRoutes(MembershipController controller) {
  final router = Router();

  router.get('/', controller.getAll);
  router.get('/<id>', controller.getById);
  router.post('/', controller.create);
  router.put('/<id>', controller.update);
  router.patch('/<id>/toggle', controller.toggleActive);

  return router;
}
