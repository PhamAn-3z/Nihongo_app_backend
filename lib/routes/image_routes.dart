import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../controllers/image_controller.dart';

Router imageRoutes(ImageController controller) {
  final router = Router();

  // API lấy chữ ký để upload ảnh lên Cloudinary
  router.get('/generate-signature', controller.generateUploadSignature);

  // API cập nhật ảnh (Xóa cũ - Lấy chữ ký cho mới)
  router.post('/update', controller.updateImage);

  // API xóa ảnh từ Cloudinary
  router.delete('/delete', controller.deleteImage);

  return router;
}
