import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../controllers/audio_controller.dart';

Router audioRoutes(AudioController controller, dynamic supabaseClient) {
  final router = Router();

  // API cấp Pre-signed URL để tải file lên Cloudflare R2
  router.post('/generate-upload-url', controller.generateUploadUrlHandler);

  // API xóa file khỏi Cloudflare R2
  router.delete('/delete', controller.deleteAudioHandler);

  // API dọn rác thủ công (Garbage Collection)
  router.post('/cleanup', (Request request) => controller.cleanupGarbageAudiosHandler(request, supabaseClient));

  return router;
}
