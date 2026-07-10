import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:supabase/supabase.dart';
import 'package:dotenv/dotenv.dart';

// Import các layer theo kiến trúc Spring Boot
import 'package:flashcard_quiz_backend/repositories/user_repository.dart';
import 'package:flashcard_quiz_backend/repositories/membership_repository.dart';
import 'package:flashcard_quiz_backend/repositories/promo_code_repository.dart';
import 'package:flashcard_quiz_backend/repositories/receipt_repository.dart';
import 'package:flashcard_quiz_backend/repositories/user_stats_repository.dart';

import 'package:flashcard_quiz_backend/services/auth_service.dart';
import 'package:flashcard_quiz_backend/services/membership_service.dart';
import 'package:flashcard_quiz_backend/services/promo_code_service.dart';
import 'package:flashcard_quiz_backend/services/receipt_service.dart';
import 'package:flashcard_quiz_backend/services/user_stats_service.dart';

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

// Import Decks
import 'package:flashcard_quiz_backend/repositories/deck_repository.dart';
import 'package:flashcard_quiz_backend/services/deck_service.dart';
import 'package:flashcard_quiz_backend/controllers/deck_controller.dart';
import 'package:flashcard_quiz_backend/routes/deck_routes.dart';
import 'package:flashcard_quiz_backend/routes/comment_routes.dart';

// Import Notifications
import 'package:flashcard_quiz_backend/repositories/notification_repository.dart';
import 'package:flashcard_quiz_backend/services/notification_service.dart';
import 'package:flashcard_quiz_backend/controllers/notification_controller.dart';
import 'package:flashcard_quiz_backend/routes/notification_routes.dart';

import 'package:flashcard_quiz_backend/repositories/notification_settings_repository.dart';
import 'package:flashcard_quiz_backend/services/notification_settings_service.dart';
import 'package:flashcard_quiz_backend/controllers/notification_settings_controller.dart';
import 'package:flashcard_quiz_backend/routes/notification_settings_routes.dart';

import 'package:flashcard_quiz_backend/repositories/fcm_token_repository.dart';
import 'package:flashcard_quiz_backend/services/fcm_service.dart';

import 'package:flashcard_quiz_backend/middlewares/auth_middleware.dart';
import 'package:flashcard_quiz_backend/middlewares/cors_middleware.dart';

import 'package:flashcard_quiz_backend/services/cron_service.dart';

void main() async {
  // Tải biến môi trường từ file .env
  final env = DotEnv(includePlatformEnvironment: true)..load();

  // 1. Cấu hình kết nối Supabase
  final String supabaseUrl = env['SUPABASE_URL'] ?? '';
  final String supabaseKey = env['SUPABASE_KEY'] ?? '';
  final String fcmServiceAccountPath = env['FIREBASE_SERVICE_ACCOUNT_PATH'] ?? 'firebase-service-account.json';

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    print('From sever.dart:  Lỗi: Chưa cấu hình SUPABASE_URL hoặc SUPABASE_KEY trong file .env. Hãy lấy key trong zalo');
    return;
  }

  final supabaseClient = SupabaseClient(supabaseUrl, supabaseKey);
  print('🔌 Đang thiết lập kết nối đến Supabase Cloud...');

  // 2. Khởi tạo các thành phần (Dependency Injection)
  final userRepository = UserRepository(supabaseClient);
  final userStatsRepository = UserStatsRepository(supabaseClient);
  final authService = AuthService(userRepository, userStatsRepository);

  final membershipRepository = MembershipRepository(supabaseClient);
  final promoCodeRepository = PromoCodeRepository(supabaseClient);
  final receiptRepository = ReceiptRepository(supabaseClient);

  // Services
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
  
  // Deck Layer
  final deckRepository = DeckRepository(supabaseClient);
  final deckService = DeckService(deckRepository, userStatsRepository);

  // Controllers
  final authController = AuthController(authService);
  final userController = UserController(userRepository);
  final membershipController = MembershipController(membershipService);
  final promoCodeController = PromoCodeController(promoCodeService);
  final receiptController = ReceiptController(receiptService);
  final userStatsController = UserStatsController(userStatsService);
  final vnpayController = VnPayController(vnpayService, receiptService);
  final deckController = DeckController(deckService);

  // Notification Layer
  final fcmTokenRepository = FcmTokenRepository(supabaseClient);
  final fcmService = FcmService(fcmServiceAccountPath);
  final notificationRepository = NotificationRepository(supabaseClient);
  final notificationService = NotificationService(notificationRepository, fcmTokenRepository, fcmService);
  final notificationController = NotificationController(notificationService);

  final notificationSettingsRepository = NotificationSettingsRepository(supabaseClient);
  final notificationSettingsService = NotificationSettingsService(notificationSettingsRepository);
  final notificationSettingsController = NotificationSettingsController(notificationSettingsService);

  // 2.1 Start Background Cleanup Task (Every 5 minutes)
  Timer.periodic(Duration(minutes: 30), (timer) async {
    print('🧹 [${DateTime.now()}] Running background cleanup: Deleting expired unpaid receipts...');
    try {
      await receiptService.cleanupExpiredReceipts();
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  });

  // Khởi động CronService nhắc nhở hết hạn
  final cronService = CronService(supabaseClient, notificationService);
  cronService.start();

  // 3. Khởi tạo Router chính
  final router = Router();

  // Mount các sub-routes
  router.mount('/api/v1/auth', authRoutes(authController));
  router.mount('/api/v1/user/', userRoutes(userController));
  router.mount('/api/v1/memberships', membershipRoutes(membershipController));
  router.mount('/api/v1/promo-codes', promoCodeRoutes(promoCodeController));
  router.mount('/api/v1/receipts', receiptRoutes(receiptController));
  router.mount('/api/v1/stats', userStatsRoutes(userStatsController));
  router.mount('/api/v1/vnpay', vnpayRoutes(vnpayController));
  router.mount('/api/v1/decks', deckRoutes(deckController));
  router.mount('/api/v1/comments', commentRoutes(deckController));
  router.mount('/api/v1/notifications', notificationRoutes(notificationController));
  router.mount('/api/v1/notification-settings', notificationSettingsRoutes(notificationSettingsController));

  // 5. Route được bảo vệ (Yêu cầu JWT Token)
  router.get('/api/v1/user/profile', (Request request) {
    return Response.ok(
      jsonEncode({"message": "Chào mừng! Bạn đã truy cập được vào dữ liệu yêu cầu bảo mật."}),
      headers: {'content-type': 'application/json'},
    );
  });

  // 6. Cấu hình Middleware Pipeline
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware()) // <-- thêm lại CORS
      .addMiddleware((Handler innerHandler) {
      return (Request request) {
        final path = request.url.path;

        // Các path yêu cầu xác thực
        bool needsAuth = path.startsWith('api/v1/profile') ||
            path.startsWith('api/v1/stats') ||
            path.startsWith('api/v1/receipts') ||
            path.contains('api/v1/comments') ||
            path.contains('api/v1/user') ||
            path.contains('api/v1/notifications') ||
            path.contains('api/v1/notification-settings') ||
            path.endsWith('auth/logout');

        // Riêng với /decks, ta yêu cầu auth trừ các endpoint công khai
        if (path.contains('api/v1/decks')) {
          needsAuth = true;
        }

        if (needsAuth) {
          return authMiddleware()(innerHandler)(request);
        }

        return innerHandler(request);
      };
  })
      .addHandler(router);

  // 6. Khởi chạy Server
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  print('🚀 SERVER ĐANG CHẠY TẠI: http://${server.address.host}:${server.port}');
  print('💡 Mẹo: Bạn có thể dùng địa chỉ IP máy tính để test nội bộ (ví dụ: http://192.168.1.x:8080)');
  
  // Khởi động SSH Tunnel tự động (Không bắt buộc, không chặn luồng chính)
  _startSshTunnel(port);
}

void _startSshTunnel(int port) async {
  try {
    print('🔑 Đang khởi tạo SSH Tunnel qua localhost.run (Vui lòng đợi giây lát)...');
    
    // Sử dụng -n để tránh treo do đợi input, và thêm -T để tắt pty
    final process = await Process.start(
      'ssh',
      ['-n', '-T', '-o', 'StrictHostKeyChecking=no', '-R', '80:127.0.0.1:$port', 'nokey@localhost.run'],
      runInShell: true,
    );

    // Biến để theo dõi xem đã lấy được URL chưa
    bool tunnelStarted = false;

    // Lắng nghe stdout để lấy URL tunnel
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.contains('.lhr.life')) {
        final regExp = RegExp(r'https://[a-zA-Z0-9\.]+');
        final match = regExp.firstMatch(line);
        if (match != null) {
          final tunnelUrl = match.group(0)!;
          VnPayController.activeTunnelUrl = tunnelUrl;
          tunnelStarted = true;
          print('\n🌍 SSH TUNNEL ĐANG HOẠT ĐỘNG TẠI: $tunnelUrl');
          print('✅ Bạn có thể dùng link này để test VNPay từ xa.\n');
        }
      }
      // Log các dòng khác từ localhost.run nếu cần debug
      if (!tunnelStarted && line.isNotEmpty) {
        // print('DEBUG SSH: $line');
      }
    });

    // Lắng nghe stderr
    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (line.toLowerCase().contains('permission denied') || line.toLowerCase().contains('failed')) {
        print('⚠️  SSH Tunnel Error: $line');
      }
    });

    // Kiểm tra nếu sau 15 giây vẫn chưa có tunnel thì thông báo cho người dùng
    Future.delayed(const Duration(seconds: 15), () {
      if (!tunnelStarted) {
        print('⏳ Việc tạo Tunnel đang mất nhiều thời gian hơn dự kiến.');
        print('👉 Bạn vẫn có thể test bằng IP nội bộ hoặc kiểm tra lại kết nối mạng/SSH.');
      }
    });

    // Đảm bảo kill SSH process khi server dừng (Ctrl+C)
    ProcessSignal.sigint.watch().listen((_) {
      process.kill();
      exit(0);
    });
  } catch (e) {
    print('❌ Không thể khởi động lệnh SSH: $e');
    print('📌 Hãy đảm bảo bạn đã cài đặt OpenSSH (gõ "ssh" trong cmd để kiểm tra).');
  }
}
