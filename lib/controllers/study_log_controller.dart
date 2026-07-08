import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/study_log_service.dart';

class StudyLogController {
  final StudyLogService _service;

  StudyLogController(this._service);

  /// Endpoint: POST /api/v1/study-logs/session-end
  Future<Response> handleSessionEnd(Request request) async {
    try {
      // 1. Lấy thông tin người dùng từ Token (thông qua AuthMiddleware)
      final payload = request.context['authPayload'] as Map<String, dynamic>?;
      if (payload == null) {
        return Response.forbidden(jsonEncode({'success': false, 'message': 'Yêu cầu Token xác thực'}));
      }

      // 2. Đọc và phân tích dữ liệu JSON từ request body
      final body = jsonDecode(await request.readAsString());
      
      // 🌟 In dữ liệu Frontend gửi về ra Terminal để kiểm tra
      print('-----------------------------------------');
      print('📥 [SESSION-END] Frontend gửi dữ liệu:');
      print(const JsonEncoder.withIndent('  ').convert(body));
      print('-----------------------------------------');
      
      // 3. Thực hiện logic nghiệp vụ thông qua Service
      final result = await _service.processSessionEnd(
        userId: payload['userId'],
        body: body,
      );

      // 4. Phản hồi kết quả thành công cho Client
      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Đã ghi nhận kết quả học tập và cập nhật thành tích!',
          'data': result
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      // Xử lý và trả về lỗi hệ thống
      return Response.internalServerError(
        body: jsonEncode({
          'success': false, 
          'message': 'Lỗi trong quá trình xử lý kết quả học tập: ${e.toString()}'
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
