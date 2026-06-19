import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:minio_new/minio.dart' as minio_lib;
import 'package:dotenv/dotenv.dart';

class AudioController {
  late final minio_lib.Minio minio;
  final String bucketName;
  final String publicDomain;

  /// Factory constructor để tối ưu hóa việc nạp file .env đúng 1 lần duy nhất
  factory AudioController() {
    final env = DotEnv()..load();
    return AudioController._internal(env);
  }

  /// Hàm khởi tạo nội bộ nhận dữ liệu env đã được nạp sẵn
  AudioController._internal(DotEnv env)
      : bucketName = env['R2_BUCKET_NAME'] ?? '',
        publicDomain = env['R2_PUBLIC_DOMAIN'] ?? '' {
    
    // Khởi tạo Minio Client để kết nối với Cloudflare R2
    minio = minio_lib.Minio(
      endPoint: (env['R2_ENDPOINT'] ?? '').replaceFirst('https://', ''),
      accessKey: env['R2_ACCESS_KEY_ID'] ?? '',
      secretKey: env['R2_SECRET_ACCESS_KEY'] ?? '',
      useSSL: true,
      region: 'auto', // Tối ưu cho Cloudflare R2
    );
  }

  /// Hàm Handler cấp Pre-signed URL
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

      // Tạo tên file độc nhất: audios/1718534000_audio.mp3
      final uniqueFileName = 'audios/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // Sinh ra uploadUrl (Phương thức PUT, thời gian 300s)
      final String uploadUrl = await minio.presignedPutObject(
        bucketName,
        uniqueFileName,
        expires: 300,
      );

      // Tạo đường link xem trực tuyến công khai
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
        body: jsonEncode({
          'success': false, 
          'message': 'Lỗi hệ thống khi sinh URL: ${e.toString()}'
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Hàm Handler xóa file khỏi Cloudflare R2
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

      // 1. Trích xuất Object Key từ URL
      final uri = Uri.parse(fileUrl);
      String objectKey = uri.path;

      // Loại bỏ dấu gạch chéo ở đầu nếu có
      if (objectKey.startsWith('/')) {
        objectKey = objectKey.substring(1);
      }

      // Kiểm tra tính hợp lệ của objectKey
      if (objectKey.isEmpty || !objectKey.startsWith('audios/')) {
        return Response.badRequest(
          body: jsonEncode({
            'success': false, 
            'message': 'Đường dẫn file không hợp lệ hoặc không thuộc thư mục audios!'
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      // 2. Thực hiện lệnh xóa trên Cloudflare R2
      await minio.removeObject(bucketName, objectKey);

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Đã xóa file khỏi Cloudflare R2 thành công!'
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false, 
          'message': 'Lỗi hệ thống khi xóa file: ${e.toString()}'
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
