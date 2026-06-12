import 'package:shelf/shelf.dart';

Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      // Lấy origin từ request, nếu không có thì mặc định là cổng bạn đang dùng
      final origin = request.headers['origin'] ?? 'http://localhost:58758';

      // Xử lý yêu cầu OPTIONS (Preflight request)
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': origin,
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
          'Access-Control-Allow-Credentials': 'true',
        });
      }

      final response = await innerHandler(request);

      // Thêm CORS headers vào mọi response dựa trên origin của request
      return response.change(headers: {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
        'Access-Control-Allow-Credentials': 'true',
      });
    };
  };
}
