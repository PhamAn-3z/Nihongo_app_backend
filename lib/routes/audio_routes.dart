import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../controllers/audio_controller.dart';

Router audioRoutes(AudioController controller) {
  final router = Router();

  // API tạo URL upload audio lên Cloudflare R2
  router.post('/generate-upload-url', controller.generateUploadUrl);

  // API cập nhật audio (Xóa cũ - Sinh URL cho mới)
  router.post('/update', controller.updateAudio);

  // API xóa audio từ Cloudflare R2
  router.delete('/delete', controller.deleteAudio);

  return router;
}
