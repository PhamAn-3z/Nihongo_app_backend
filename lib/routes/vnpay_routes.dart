import 'package:shelf_router/shelf_router.dart';
import '../controllers/vnpay_controller.dart';

Router vnpayRoutes(VNPayController controller) {
  final router = Router();

  router.post('/create_payment_url', controller.createPaymentUrl);
  router.get('/vnpay_return', controller.vnpayReturn);
  router.get('/vnpay_ipn', controller.vnpayIpn);

  return router;
}
