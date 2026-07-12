import 'package:shelf_router/shelf_router.dart';
import '../controllers/receipt_controller.dart';

Router receiptRoutes(ReceiptController controller) {
  final router = Router();
  router.get('/', controller.getAll);
  router.get('/my', controller.getMyReceipts);
  router.get('/user/<userId>', controller.getByUserId);
  router.post('/', controller.create);
  router.put('/<id>/pay', controller.pay);
  router.put('/<id>', controller.update);
  router.delete('/cleanup', controller.cleanup);
  return router;
}
