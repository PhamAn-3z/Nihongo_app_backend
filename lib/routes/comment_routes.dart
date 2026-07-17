import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../controllers/deck_controller.dart';

Router commentRoutes(DeckController controller) {
  final router = Router();

  // Xóa bình luận
  router.delete('/<comment_id>', controller.deleteComment);

  // Toggle Like bình luận (Thích/Bỏ thích)
  router.post('/<comment_id>/toggle-like', controller.toggleCommentLike);

  return router;
}
