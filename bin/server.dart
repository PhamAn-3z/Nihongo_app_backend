import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:supabase/supabase.dart';
import 'package:dotenv/dotenv.dart';

// Import các layer
import 'package:flashcard_quiz_backend/repositories/user_repository.dart';
import 'package:flashcard_quiz_backend/repositories/membership_repository.dart';
import 'package:flashcard_quiz_backend/repositories/promo_code_repository.dart';
import 'package:flashcard_quiz_backend/repositories/receipt_repository.dart';
import 'package:flashcard_quiz_backend/repositories/user_stats_repository.dart';
import 'package:flashcard_quiz_backend/repositories/email_verification_repository.dart';

import 'package:flashcard_quiz_backend/services/auth_service.dart';
import 'package:flashcard_quiz_backend/services/membership_service.dart';
import 'package:flashcard_quiz_backend/services/promo_code_service.dart';
import 'package:flashcard_quiz_backend/services/receipt_service.dart';
import 'package:flashcard_quiz_backend/services/user_stats_service.dart';
import 'package:flashcard_quiz_backend/services/email_service.dart';

import 'package:flashcard_quiz_backend/controllers/auth_controller.dart';
import 'package:flashcard_quiz_backend/controllers/user_controller.dart';
import 'package:flashcard_quiz_backend/controllers/membership_controller.dart';
import 'package:flashcard_quiz_backend/controllers/promo_code_controller.dart';
import 'package:flashcard_quiz_backend/controllers/receipt_controller.dart';
import 'package:flashcard_quiz_backend/controllers/user_stats_controller.dart';

import 'package:flashcard_quiz_backend/routes/auth_routes.dart';
import 'package:flashcard_quiz_backend/routes/user_routes.dart';
import 'package:flashcard_quiz_backend/routes/membership_routes.dart';
import 'package:flashcard_quiz_backend/routes/promo_code_routes.dart';
import 'package:flashcard_quiz_backend/routes/receipt_routes.dart';
import 'package:flashcard_quiz_backend/routes/user_stats_routes.dart';
import 'package:flashcard_quiz_backend/routes/vnpay_routes.dart';

import 'package:flashcard_quiz_backend/services/vnpay_service.dart';
import 'package:flashcard_quiz_backend/controllers/vnpay_controller.dart';

import 'package:flashcard_quiz_backend/repositories/deck_repository.dart';
import 'package:flashcard_quiz_backend/services/deck_service.dart';
import 'package:flashcard_quiz_backend/controllers/deck_controller.dart';
import 'package:flashcard_quiz_backend/routes/deck_routes.dart';
import 'package:flashcard_quiz_backend/routes/comment_routes.dart';

import 'package:flashcard_quiz_backend/middlewares/auth_middleware.dart';
import 'package:flashcard_quiz_backend/middlewares/cors_middleware.dart';

void main() async {
  // Load environment variables
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('❌ LỖI: Không tìm thấy file .env tại ${envFile.absolute.path}');
  }
  
  var env = DotEnv(includePlatformEnvironment: true)..load();

  // 1. Cấu hình kết nối Supabase
  final String supabaseUrl = 'https://xdekwfqnhrohydgejhdk.supabase.co';
  final String supabaseKey = env['SUPABASE_KEY'] ?? '';

  final supabaseClient = SupabaseClient(supabaseUrl, supabaseKey);
  print('🔌 Đang thiết lập kết nối đến Supabase Cloud...');

  // 2. Kiểm tra và log biến môi trường (không in pass)
  final String smtpEmail = env['SMTP_EMAIL'] ?? '';
  final String smtpPassword = env['SMTP_PASSWORD'] ?? '';
  
  if (smtpEmail.isEmpty) print('⚠️ SMTP_EMAIL is missing in .env');
  else print('📧 SMTP Email configured: $smtpEmail');
  
  if (smtpPassword.isEmpty) print('⚠️ SMTP_PASSWORD is missing in .env');
  else print('📧 SMTP Password: configured (hidden)');

  final emailService = EmailService(smtpEmail, smtpPassword);

  // 3. Khởi tạo Repositories
  final userRepository = UserRepository(supabaseClient);
  final emailVerificationRepository = EmailVerificationRepository(supabaseClient);
  final membershipRepository = MembershipRepository(supabaseClient);
  final promoCodeRepository = PromoCodeRepository(supabaseClient);
  final receiptRepository = ReceiptRepository(supabaseClient);
  final userStatsRepository = UserStatsRepository(supabaseClient);

  // 4. Khởi tạo Services
  final authService = AuthService(
    userRepository: userRepository,
    emailVerificationRepository: emailVerificationRepository,
    emailService: emailService,
  );
  final membershipService = MembershipService(membershipRepository);
  final promoCodeService = PromoCodeService(promoCodeRepository);
  final receiptService = ReceiptService(
    receiptRepository,
    membershipRepository,
    promoCodeRepository,
  );
  final userStatsService = UserStatsService(userStatsRepository);
  final vnpayService = VnPayService();
  final deckRepository = DeckRepository(supabaseClient);
  final deckService = DeckService(deckRepository);

  // 5. Khởi tạo Controllers
  final authController = AuthController(authService);
  final userController = UserController(userRepository);
  final membershipController = MembershipController(membershipService);
  final promoCodeController = PromoCodeController(promoCodeService);
  final receiptController = ReceiptController(receiptService);
  final userStatsController = UserStatsController(userStatsService);
  final vnpayController = VnPayController(vnpayService, receiptService);
  final deckController = DeckController(deckService);

  // Periodic Cleanup
  Timer.periodic(Duration(minutes: 5), (timer) async {
    try {
      await receiptService.cleanupExpiredReceipts();
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  });

  final router = Router();
  router.mount('/api/v1/auth', authRoutes(authController));
  router.mount('/api/v1/user/', userRoutes(userController));
  router.mount('/api/v1/memberships', membershipRoutes(membershipController));
  router.mount('/api/v1/promo-codes', promoCodeRoutes(promoCodeController));
  router.mount('/api/v1/receipts', receiptRoutes(receiptController));
  router.mount('/api/v1/stats', userStatsRoutes(userStatsController));
  router.mount('/api/v1/vnpay', vnpayRoutes(vnpayController));
  router.mount('/api/v1/decks', deckRoutes(deckController));
  router.mount('/api/v1/comments', commentRoutes(deckController));

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addMiddleware((Handler innerHandler) {
    return (Request request) {
      if (request.url.path.contains('api/v1/user') ||
          request.url.path.startsWith('api/v1/stats') ||
          request.url.path.startsWith('api/v1/receipts') ||
          request.url.path.contains('api/v1/decks') ||
          request.url.path.contains('api/v1/comments') ||
          request.url.path.endsWith('auth/logout')) {
        return authMiddleware()(innerHandler)(request);
      }
      return innerHandler(request);
    };
  })
      .addHandler(router);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  print('🚀 SERVER ĐANG CHẠY TẠI: http://${server.address.host}:${server.port}');
}
