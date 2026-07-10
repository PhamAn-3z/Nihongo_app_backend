import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/cloudinary_service.dart';

class ImageController {
  final CloudinaryService _cloudinaryService;

  ImageController(this._cloudinaryService);

  Future<Response> generateUploadSignature(Request request) async {
    try {
      final data = _cloudinaryService.generateUploadSignature();

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Cloudinary upload signature generated",
          "data": data
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"success": false, "message": e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> updateImage(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final String? oldPublicId = body['oldPublicId'];

      // 1. Xóa ảnh cũ nếu có cung cấp oldPublicId
      if (oldPublicId != null && oldPublicId.isNotEmpty) {
        try {
          await _cloudinaryService.deleteImage(oldPublicId);
        } catch (e) {
          // Log lỗi nhưng không chặn tiến trình tạo signature mới
          print('Warning: Could not delete old image: $e');
        }
      }

      // 2. Tạo Signature mới cho ảnh mới
      final data = _cloudinaryService.generateUploadSignature();

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Old image deleted (if existed) and new signature generated",
          "data": data
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"success": false, "message": e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> deleteImage(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final String? publicId = body['publicId'];

      if (publicId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'publicId is required'}));
      }

      await _cloudinaryService.deleteImage(publicId);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Image deleted successfully from Cloudinary"
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"success": false, "message": e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
