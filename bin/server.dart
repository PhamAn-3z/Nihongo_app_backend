import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:supabase/supabase.dart';
import 'package:dotenv/dotenv.dart';

// Repositories
import 'package:flashcard_quiz_backend/repositories/user_repository.dart';
import 'package:flashcard_quiz_backend/repositories/membership_repository.dart';
import 'package:flashcard_quiz_backend/repositories/promo_code_repository.dart';
import 'package:flashcard_quiz_backend/repositories/receipt_repository.dart';
import 'package:flashcard_quiz_backend/repositories/user_stats_repository.dart';
import 'package:flashcard_quiz_backend/repositories/email_verification_repository.dart';
import 'package:flashcard_quiz_backend/repositories/deck_repository.dart';
import 'package:flashcard_quiz_backend/repositories/study_log_repository.dart';
import 'package:flashcard_quiz_backend/repositories/notification_repository.dart';
import 'package:flashcard_quiz_backend/repositories/translation_repository.dart';
import 'package:flashcard_quiz_backend/repositories/moderation_repository.dart';

// Services
import 'package:flashcard_quiz_backend/services/auth_service.dart';
import 'package:flashcard_quiz_backend/services/membership_service.dart';
import 'package:flashcard_quiz_backend/services/promo_code_service.dart';
import 'package:flashcard_quiz_backend/services/receipt_service.dart';
import 'package:flashcard_quiz_backend/services/user_stats_service.dart';
import 'package:flashcard_quiz_backend/services/email_service.dart';
import 'package:flashcard_quiz_backend/services/vnpay_service.dart';
import 'package:flashcard_quiz_backend/services/deck_service.dart';
import 'package:flashcard_quiz_backend/services/notification_service.dart';
import 'package:flashcard_quiz_backend/services/study_log_service.dart';
import 'package:flashcard_quiz_backend/services/r2_service.dart';
import 'package:flashcard_quiz_backend/services/cloudinary_service.dart';
import 'package:flashcard_quiz_backend/services/gemini_service.dart';
import 'package:flashcard_quiz_backend/services/translation_service.dart';
import 'package:flashcard_quiz_backend/services/moderation_service.dart';

// Controllers
import 'package:flashcard_quiz_backend/controllers/auth_controller.dart';
import 'package:flashcard_quiz_backend/controllers/user_controller.dart';
import 'package:flashcard_quiz_backend/controllers/membership_controller.dart';
import 'package:flashcard_quiz_backend/controllers/promo_code_controller.dart';
import 'package:flashcard_quiz_backend/controllers/receipt_controller.dart';
import 'package:flashcard_quiz_backend/controllers/user_stats_controller.dart';
import 'package:flashcard_quiz_backend/controllers/vnpay_controller.dart';
import 'package:flashcard_quiz_backend/controllers/deck_controller.dart';
import 'package:flashcard_quiz_backend/controllers/notification_controller.dart';
import 'package:flashcard_quiz_backend/controllers/study_log_controller.dart';
import 'package:flashcard_quiz_backend/controllers/audio_controller.dart';
import 'package:flashcard_quiz_backend/controllers/image_controller.dart';
import 'package:flashcard_quiz_backend/controllers/translation_controller.dart';
import 'package:flashcard_quiz_backend/controllers/admin_moderation_controller.dart';

// Routes
import 'package:flashcard_quiz_backend/routes/auth_routes.dart';
import 'package:flashcard_quiz_backend/routes/user_routes.dart';
import 'package:flashcard_quiz_backend/routes/membership_routes.dart';
import 'package:flashcard_quiz_backend/routes/promo_code_routes.dart';
import 'package:flashcard_quiz_backend/routes/receipt_routes.dart';
import 'package:flashcard_quiz_backend/routes/user_stats_routes.dart';
import 'package:flashcard_quiz_backend/routes/vnpay_routes.dart';
import 'package:flashcard_quiz_backend/routes/deck_routes.dart';
import 'package:flashcard_quiz_backend/routes/comment_routes.dart';
import 'package:flashcard_quiz_backend/routes/notification_routes.dart';
import 'package:flashcard_quiz_backend/routes/study_log_routes.dart';
import 'package:flashcard_quiz_backend/routes/audio_routes.dart';
import 'package:flashcard_quiz_backend/routes/image_routes.dart';
import 'package:flashcard_quiz_backend/routes/translation_routes.dart';
import 'package:flashcard_quiz_backend/routes/admin_moderation_routes.dart';

import 'package:flashcard_quiz_backend/middlewares/auth_middleware.dart';
import 'package:flashcard_quiz_backend/middlewares/cors_middleware.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load();

  final String supabaseUrl = env['SUPABASE_URL'] ?? '';
  final String supabaseKey = env['SUPABASE_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    print('❌ Lỗi: Chưa cấu hình SUPABASE_URL hoặc SUPABASE_KEY trong file .env');
    return;
  }

  final supabaseClient = SupabaseClient(supabaseUrl, supabaseKey);
  print('🔌 Đang thiết lập kết nối đến Supabase Cloud...');

  // SMTP Config
  final String smtpEmail = env['SMTP_EMAIL'] ?? '';
  final String smtpPassword = env['SMTP_PASSWORD'] ?? '';
  final emailService = EmailService(smtpEmail, smtpPassword);

  // Gemini Config
  final String geminiApiKey = env['GEMINI_API_KEY'] ?? '';
  final geminiService = GeminiService(geminiApiKey);

  // Repositories
  final userRepository = UserRepository(supabaseClient);
  final userStatsRepository = UserStatsRepository(supabaseClient);
  final emailVerificationRepository = EmailVerificationRepository(supabaseClient);
  final moderationRepository = ModerationRepository(supabaseClient);
  final membershipRepository = MembershipRepository(supabaseClient);
  final promoCodeRepository = PromoCodeRepository(supabaseClient);
  final receiptRepository = ReceiptRepository(supabaseClient);
  final deckRepository = DeckRepository(supabaseClient);
  final studyLogRepo = StudyLogRepository(supabaseClient);
  final notificationRepository = NotificationRepository(supabaseClient);
  final translationRepository = TranslationRepository(supabaseClient);

  // Services
  final notificationService = NotificationService(notificationRepository);
  final moderationService = ModerationService(moderationRepository, userRepository, notificationService);
  final authService = AuthService(
    userRepository: userRepository,
    userStatsRepository: userStatsRepository,
    emailVerificationRepository: emailVerificationRepository,
    emailService: emailService,
    moderationService: moderationService,
  );
  final membershipService = MembershipService(membershipRepository);
  final promoCodeService = PromoCodeService(promoCodeRepository);
  final receiptService = ReceiptService(
    receiptRepository,
    membershipRepository,
    promoCodeRepository,
    userStatsRepository,
  );
  final userStatsService = UserStatsService(userStatsRepository);
  final vnpayService = VnPayService();
  final deckService = DeckService(deckRepository);
  final studyLogService = StudyLogService(studyLogRepo);
  final translationService = TranslationService(translationRepository, geminiService);

  // Audio/R2 Config
  final r2Service = R2Service(
    accessKey: env['R2_ACCESS_KEY_ID']?.trim() ?? '',
    secretKey: env['R2_SECRET_ACCESS_KEY']?.trim() ?? '',
    endpoint: env['R2_ENDPOINT']?.trim() ?? '',
    bucketName: env['R2_BUCKET_NAME']?.trim() ?? '',
    publicDomain: env['R2_PUBLIC_DOMAIN']?.trim() ?? '',
  );

  final cloudinaryService = CloudinaryService(
    cloudName: env['CLOUDINARY_CLOUD_NAME']?.trim() ?? '',
    apiKey: env['CLOUDINARY_API_KEY']?.trim() ?? '',
    apiSecret: env['CLOUDINARY_API_SECRET']?.trim() ?? '',
    uploadPreset: env['CLOUDINARY_UPLOAD_PRESET']?.trim() ?? 'ml_default',
  );

  // Controllers
  final authController = AuthController(authService);
  final userController = UserController(userRepository);
  final moderationController = AdminModerationController(moderationService, userRepository);
  final membershipController = MembershipController(membershipService);
  final promoCodeController = PromoCodeController(promoCodeService);
  final receiptController = ReceiptController(receiptService);
  final userStatsController = UserStatsController(userStatsService);
  final vnpayController = VnPayController(vnpayService, receiptService);
  final deckController = DeckController(deckService);
  final studyLogController = StudyLogController(studyLogService);
  final notificationController = NotificationController(notificationService);
  final audioController = AudioController(r2Service);
  final imageController = ImageController(cloudinaryService);
  final translationController = TranslationController(translationService);

  // Background Cleanup Task
  Timer.periodic(Duration(minutes: 30), (timer) async {
    print('🧹 [${DateTime.now()}] Running background cleanup: Deleting expired unpaid receipts...');
    try {
      await receiptService.cleanupExpiredReceipts();
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  });

  final router = Router();

  router.mount('/api/v1/auth', authRoutes(authController));
  router.mount('/api/v1/user/', userRoutes(userController));
  router.mount('/api/v1/admin', adminModerationRoutes(moderationController));
  router.mount('/api/v1/memberships', membershipRoutes(membershipController));
  router.mount('/api/v1/promo-codes', promoCodeRoutes(promoCodeController));
  router.mount('/api/v1/receipts', receiptRoutes(receiptController));
  router.mount('/api/v1/stats', userStatsRoutes(userStatsController));
  router.mount('/api/v1/vnpay', vnpayRoutes(vnpayController));
  router.mount('/api/v1/decks', deckRoutes(deckController));
  router.mount('/api/v1/comments', commentRoutes(deckController));
  router.mount('/api/v1/notifications', notificationRoutes(notificationController));
  router.mount('/api/v1/study-logs', studyLogRoutes(studyLogController));
  router.mount('/api/v1/audio', audioRoutes(audioController));
  router.mount('/api/v1/images', imageRoutes(imageController));
  router.mount('/api/v1/translate', translationRoutes(translationController));

  router.get('/api/v1/user/profile', (Request request) {
    return Response.ok(
      jsonEncode({"message": "Chào mừng! Bạn đã truy cập được vào dữ liệu yêu cầu bảo mật."}),
      headers: {'content-type': 'application/json'},
    );
  });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addMiddleware((Handler innerHandler) {
    return (Request request) {
      final path = request.url.path;

      // Whitelist các routes công khai
      if (path.contains('auth/login') || 
          path.contains('auth/register') || 
          path.contains('auth/verify-otp') || 
          path.contains('auth/resend-otp') ||
          path.contains('api/v1/decks/explore')) {
        return innerHandler(request);
      }

      if (path.startsWith('api/v1/profile') ||
          path.startsWith('api/v1/stats') ||
          path.startsWith('api/v1/receipts')||
          path.contains('api/v1/admin') ||
          path.contains('api/v1/decks') ||
          path.contains('api/v1/comments') ||
          path.contains('api/v1/user') ||
          path.contains('api/v1/audio') ||
          path.contains('api/v1/images') ||
          path.contains('api/v1/notifications') ||
          path.contains('api/v1/study-logs') ||
          path.contains('api/v1/translate') ||
          path.endsWith('auth/logout')) {
        return authMiddleware(moderationService)(innerHandler)(request);
      }

      return innerHandler(request);
    };
  })
  .addHandler(router);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  print('🚀 SERVER ĐANG CHẠY TẠI: http://${server.address.host}:${server.port}');
  
  _startSshTunnel(port);
}

void _startSshTunnel(int port) async {
  try {
    print('🔑 Đang khởi tạo SSH Tunnel qua localhost.run...');
    final process = await Process.start(
      'ssh',
      ['-n', '-T', '-o', 'StrictHostKeyChecking=no', '-R', '80:127.0.0.1:$port', 'nokey@localhost.run'],
      runInShell: true,
    );

    bool tunnelStarted = false;
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.contains('.lhr.life')) {
        final regExp = RegExp(r'https://[a-zA-Z0-9\.]+');
        final match = regExp.firstMatch(line);
        if (match != null) {
          final tunnelUrl = match.group(0)!;
          VnPayController.activeTunnelUrl = tunnelUrl;
          tunnelStarted = true;
          print('🌍 SSH TUNNEL ĐANG HOẠT ĐỘNG TẠI: $tunnelUrl');
        }
      }
    });

    ProcessSignal.sigint.watch().listen((_) {
      process.kill();
      exit(0);
    });
  } catch (e) {
    print('❌ Không thể khởi động lệnh SSH: $e');
  }
}
