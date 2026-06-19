import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:minio/minio.dart' as minio_lib;
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

  /// API dọn dẹp file rác trên Cloudflare R2 (Đối chiếu với bảng terms trong DB)
  Future<Response> cleanupGarbageAudiosHandler(Request request, dynamic supabaseClient) async {
    try {
      // 1. Quét toàn bộ danh sách file hiện có trên R2 trong thư mục audios/
      final List<String> r2Keys = [];
      
      // Sử dụng listObjectsV2 của thư viện chính chủ minio
      final objectsStream = minio.listObjectsV2(bucketName, prefix: 'audios/', recursive: true);

      await for (final result in objectsStream) {
        for (final obj in result.objects) {
          if (obj.key != null) {
            r2Keys.add(obj.key!);
          }
        }
      }

      if (r2Keys.isEmpty) {
        return Response.ok(
          jsonEncode({'success': true, 'message': 'Kho lưu trữ R2 hiện đang trống.'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // 2. Truy vấn Database lấy toàn bộ audio_url đang được sử dụng
      final List<dynamic> dbResponse = await supabaseClient.from('terms').select('content');

      final Set<String> validKeys = {};
      for (var row in dbResponse) {
        final dynamic content = row['content'];
        if (content != null && content is Map && content.containsKey('audio_url')) {
          final String? audioUrl = content['audio_url'];
          if (audioUrl != null && audioUrl.isNotEmpty) {
            // Trích xuất Key từ URL (ví dụ: https://.../audios/123.mp3 -> audios/123.mp3)
            final uri = Uri.parse(audioUrl);
            String path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
            validKeys.add(path);
          }
        }
      }

      // 3. Tìm file rác (Có trên R2 nhưng KHÔNG có trong DB)
      final List<String> garbageKeys = r2Keys.where((key) => !validKeys.contains(key)).toList();

      if (garbageKeys.isEmpty) {
        return Response.ok(
          jsonEncode({'success': true, 'message': 'Hệ thống sạch sẽ, không có file rác.'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // 5. Thực hiện xóa từng file một trên R2 để đảm bảo lệnh được thực thi
      final List<String> deletedFiles = [];
      final List<String> failedFiles = [];

      for (final key in garbageKeys) {
        try {
          await minio.removeObject(bucketName, key);
          deletedFiles.add(key);
        } catch (e) {
          failedFiles.add('$key (Lỗi: $e)');
        }
      }

      if (deletedFiles.isEmpty && failedFiles.isNotEmpty) {
        return Response.internalServerError(
          body: jsonEncode({
            'success': false,
            'message': 'Không thể xóa bất kỳ file nào.',
            'errors': failedFiles,
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': failedFiles.isEmpty 
              ? 'Tiến trình dọn rác hoàn tất!' 
              : 'Dọn rác hoàn tất một phần (có một số lỗi).',
          'data': {
            'total_scanned_files': r2Keys.length,
            'deleted_garbage_count': deletedFiles.length,
            'deleted_files': deletedFiles,
            'failed_files': failedFiles,
          }
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Lỗi hệ thống khi dọn rác: ${e.toString()}'
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
