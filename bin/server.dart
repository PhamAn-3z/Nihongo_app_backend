import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:supabase/supabase.dart';

// Import các layer theo kiến trúc Spring Boot
import 'package:flashcard_quiz_backend/repositories/user_repository.dart';
import 'package:flashcard_quiz_backend/services/auth_service.dart';
import 'package:flashcard_quiz_backend/controllers/auth_controller.dart';
import 'package:flashcard_quiz_backend/routes/auth_routes.dart';
import 'package:flashcard_quiz_backend/middlewares/auth_middleware.dart';

void main() async {
  // 1. Cấu hình kết nối Supabase
  final String supabaseUrl = 'https://xdekwfqnhrohydgejhdk.supabase.co';
  final String supabaseKey = 'sb_publishable_Mk288brWkRYpm14YH2xAOw_sAb6qcyW';

  final supabaseClient = SupabaseClient(supabaseUrl, supabaseKey);
  print('🔌 Đang thiết lập kết nối đến Supabase Cloud...');

  // 2. Khởi tạo các thành phần (Dependency Injection)
  final userRepository = UserRepository(supabaseClient);
  final authService = AuthService(userRepository);
  final authController = AuthController(authService);

  final router = Router();

  // Đăng ký các route Authentication (Public)
  router.mount('/api/v1/auth/', authRoutes(authController));

  // 3. API Decks (Public)
  router.get('/api/v1/decks', (Request request) async {
    try {
      final List<dynamic> response = await supabaseClient.from('decks').select();
      return Response.ok(
        jsonEncode({"status": "success", "data": response}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"status": "error", "message": "Lỗi kết nối DB: $e"}),
        headers: {'content-type': 'application/json'},
      );
    }
  });

  // 4. Route được bảo vệ (Yêu cầu JWT Token)
  // Ví dụ: Endpoint lấy thông tin cá nhân (Profile)
  router.get('/api/v1/profile', (Request request) {
    return Response.ok(
      jsonEncode({"message": "Chào mừng! Bạn đã truy cập được vào dữ liệu yêu cầu bảo mật."}),
      headers: {'content-type': 'application/json'},
    );
  });

  // 5. Cấu hình Middleware Pipeline
  final handler = Pipeline()
      .addMiddleware(logRequests()) // Log mọi request để dễ debug
      .addHandler((Request request) {
        // Áp dụng authMiddleware cho các endpoint cần bảo mật (ví dụ: profile)
        if (request.url.path.startsWith('api/v1/profile')) {
          return authMiddleware()(router)(request);
        }
        return router(request);
      });

  // 6. Khởi chạy Server
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);

  print('🚀 SERVER ĐANG CHẠY TẠI: http://${server.address.host}:${server.port}');
}
