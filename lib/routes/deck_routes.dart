import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../controllers/deck_controller.dart';

Router deckRoutes(DeckController controller) {
  final router = Router();

  // API Bulk Import
  router.post('/bulk-import', controller.bulkImportCreateDeck);
  
  // Lấy danh sách bộ đề
  router.get('/', controller.getAllDecks);

  // Lấy danh sách bộ đề của user (dạng cây)
  router.get('/my-decks', controller.getUserDecksTree);

  // Lấy dữ liệu học tập của một bộ đề cụ thể
  router.get('/<id>/study', controller.getDeckStudyData);

  // Xóa bộ đề vĩnh viễn
  router.delete('/<id>', controller.deleteDeck);

  // Toggle Favorite (Bật/Tắt yêu thích)
  router.patch('/<id>/toggle-favorite', controller.toggleFavorite);

  return router;
}
