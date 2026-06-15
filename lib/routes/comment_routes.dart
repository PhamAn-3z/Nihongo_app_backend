import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../controllers/deck_controller.dart';

Router commentRoutes(DeckController controller) {
  final router = Router();

  // Xóa bình luận
  router.delete('/<comment_id>', controller.deleteComment);

  return router;
}
