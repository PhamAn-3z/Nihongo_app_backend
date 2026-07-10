import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/r2_service.dart';

class AudioController {
  final R2Service _r2service;

  AudioController(this._r2service);

  Future<Response> generateUploadUrl(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final String? fileName = body['fileName'];
      final String? contentType = body['contentType'] ?? 'audio/mpeg';

      if (fileName == null) {
        return Response.badRequest(body: jsonEncode({'message': 'fileName is required'}));
      }

      // Tạo object key duy nhất (ví dụ: timestamp + fileName)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final objectKey = 'audios/$timestamp-$fileName';

      final uploadUrl = _r2service.generatePresignedUrl(objectKey, 'PUT');
      final publicUrl = _r2service.getPublicUrl(objectKey);

      return Response.ok(
        jsonEncode({
          "success": true,
          "data": {
            "uploadUrl": uploadUrl,
            "publicUrl": publicUrl,
            "objectKey": objectKey
          }
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

  Future<Response> updateAudio(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final String? oldObjectKey = body['oldObjectKey'];
      final String? newFileName = body['newFileName'];
      final String? contentType = body['contentType'] ?? 'audio/mpeg';

      if (newFileName == null) {
        return Response.badRequest(body: jsonEncode({'message': 'newFileName is required'}));
      }

      // 1. Xóa file cũ nếu có cung cấp oldObjectKey
      if (oldObjectKey != null && oldObjectKey.isNotEmpty) {
        try {
          await _r2service.deleteObject(oldObjectKey);
        } catch (e) {
          // Log lỗi nhưng không chặn tiến trình tạo URL mới
          print('Warning: Could not delete old audio file: $e');
        }
      }

      // 2. Tạo URL upload cho file mới
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newObjectKey = 'audios/$timestamp-$newFileName';
      final uploadUrl = _r2service.generatePresignedUrl(newObjectKey, 'PUT');
      final publicUrl = _r2service.getPublicUrl(newObjectKey);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Old file deleted (if existed) and new upload URL generated",
          "data": {
            "uploadUrl": uploadUrl,
            "publicUrl": publicUrl,
            "objectKey": newObjectKey
          }
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

  Future<Response> deleteAudio(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final String? objectKey = body['objectKey'];

      if (objectKey == null) {
        return Response.badRequest(body: jsonEncode({'message': 'objectKey is required'}));
      }

      await _r2service.deleteObject(objectKey);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Audio file deleted successfully"
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
