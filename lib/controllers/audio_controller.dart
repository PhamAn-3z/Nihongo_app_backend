import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:minio_new/minio.dart';
import 'package:dotenv/dotenv.dart';

class AudioController {
  late final Minio minio;
  final String bucketName;
  final String publicDomain;

  /// Factory constructor
  factory AudioController() {
    final env = DotEnv()..load();
    return AudioController._internal(env);
  }

  AudioController._internal(DotEnv env)
      : bucketName = env['R2_BUCKET_NAME'] ?? '',
        publicDomain = env['R2_PUBLIC_DOMAIN'] ?? '' {
    
    minio = Minio(
      endPoint: (env['R2_ENDPOINT'] ?? '').replaceFirst('https://', ''),
      accessKey: env['R2_ACCESS_KEY_ID'] ?? '',
      secretKey: env['R2_SECRET_ACCESS_KEY'] ?? '',
      useSSL: true,
      region: 'auto', // 🌟 Quay lại 'auto' theo khuyến nghị của Cloudflare
    );
  }

  Future<Response> generateUploadUrlHandler(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final String? fileName = body['fileName'];

      if (fileName == null || fileName.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Thiếu tham số fileName!'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final uniqueFileName = 'audios/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // 1. Sinh ra Pre-signed URL "Sạch" (Không thêm tham số thủ công vào URL)
      final String uploadUrl = await minio.presignedPutObject(
        bucketName,
        uniqueFileName,
        expires: 300,
      );

      final String fileUrl = '$publicDomain/$uniqueFileName';

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Sinh liên kết tải lên thành công!',
          'data': {
            'uploadUrl': uploadUrl,
            'fileUrl': fileUrl,
          }
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': 'Lỗi hệ thống: ${e.toString()}'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> deleteAudioHandler(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final String? fileUrl = body['fileUrl'];

      if (fileUrl == null || fileUrl.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Thiếu tham số fileUrl!'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final uri = Uri.parse(fileUrl);
      String objectKey = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;

      if (!objectKey.startsWith('audios/')) {
        return Response.badRequest(
          body: jsonEncode({'success': false, 'message': 'Đường dẫn không hợp lệ!'}),
          headers: {'content-type': 'application/json'},
        );
      }

      await minio.removeObject(bucketName, objectKey);

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Đã xóa file thành công!'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'message': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // Tạm thời vô hiệu hóa logic cleanup gây lỗi maxKeys trên minio_new 
  // hoặc dùng logic đơn giản hơn nếu cần.
  Future<Response> cleanupGarbageAudiosHandler(Request request, dynamic supabaseClient) async {
    return Response.ok(
      jsonEncode({'success': true, 'message': 'Tính năng dọn rác đang được bảo trì cho thư viện cũ.'}),
      headers: {'content-type': 'application/json'},
    );
  }
}
