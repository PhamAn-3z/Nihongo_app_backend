import 'package:shelf_router/shelf_router.dart';
import '../controllers/vnpay_controller.dart';

Router vnpayRoutes(VnPayController controller) {
  final router = Router();

  // POST /api/v1/vnpay/create
  router.post('/create', controller.createPayment);


  // GET /api/v1/vnpay/return
  router.get('/return', controller.vnpayReturn);

  // GET /api/v1/vnpay/ipn
  router.get('/ipn', controller.vnpayIpn);

  return router;
}
