import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:supabase/supabase.dart';

// Import các layer
import 'package:flashcard_quiz_backend/repositories/user_repository.dart';
import 'package:flashcard_quiz_backend/services/auth_service.dart';
import 'package:flashcard_quiz_backend/controllers/auth_controller.dart';
import 'package:flashcard_quiz_backend/controllers/user_controller.dart';
import 'package:flashcard_quiz_backend/routes/auth_routes.dart';
import 'package:flashcard_quiz_backend/routes/user_routes.dart';
import 'package:flashcard_quiz_backend/middlewares/auth_middleware.dart';

void main() async {
  final String supabaseUrl = 'https://xdekwfqnhrohydgejhdk.supabase.co';
  final String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhkZWt3ZnFuaHJvaHlkZ2VqaGRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNjk1NTIsImV4cCI6MjA5NDk0NTU1Mn0.entE4M0y_37r-PuUrZ-YO879QMfuMGQJe-S8QrYRU-4';

  final supabaseClient = SupabaseClient(supabaseUrl, supabaseKey);
  print('🔌 Đang kết nối Supabase...');

  final userRepository = UserRepository(supabaseClient);
  final authService = AuthService(userRepository);
  final authController = AuthController(authService);
  // Cập nhật UserController để nhận userRepository (Dependency Injection)
  final userController = UserController(userRepository);

  final router = Router();

  // Mount routes
  router.mount('/api/v1/auth/', authRoutes(authController));
  router.mount('/api/v1/user/', userRoutes(userController));

  // Public Decks API
  router.get('/api/v1/decks', (Request request) async {
    final response = await supabaseClient.from('decks').select();
    return Response.ok(jsonEncode(response), headers: {'content-type': 'application/json'});
  });

  // Pipeline xử lý Request
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) {
        // Kiểm tra xem path có thuộc vùng bảo mật /user/ hoặc là logout không
        if (request.url.path.contains('api/v1/user') || request.url.path.endsWith('auth/logout')) {
          return authMiddleware()(router)(request);
        }
        
        return router(request);
      });

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('🚀 Server đang chạy tại http://${server.address.host}:${server.port}');
}
