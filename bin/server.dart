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
  final String supabaseKey = 'sb_publishable_Mk288brWkRYpm14YH2xAOw_sAb6qcyW';

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
        // Kiểm tra xem path có thuộc vùng bảo mật /user/ không
        if (request.url.path.contains('api/v1/user')) {
          return authMiddleware()(router)(request);
        }
        
        return router(request);
      });

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('🚀 Server đang chạy tại http://${server.address.host}:${server.port}');
}
