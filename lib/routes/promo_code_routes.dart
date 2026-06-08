import 'package:shelf_router/shelf_router.dart';
import '../controllers/promo_code_controller.dart';

Router promoCodeRoutes(PromoCodeController controller) {
  final router = Router();
  router.get('/', controller.getAll);
  router.get('/active', controller.getActive);
  router.get('/<code>', controller.getByCode);
  router.post('/', controller.create);
  router.put('/<id>', controller.update);
  router.patch('/<id>/toggle-expired', controller.toggleExpired);
  return router;
}
