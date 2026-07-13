import 'dart:async';
import 'package:supabase/supabase.dart';
import '../services/notification_service.dart';

class CronService {
  final SupabaseClient supabase;
  final NotificationService notificationService;
  Timer? _expiryCheckTimer;

  CronService(this.supabase, this.notificationService);

  void start() {
    // Chạy lần đầu sau khi khởi động 10 giây (rút ngắn để dễ test)
    Timer(const Duration(seconds: 10), () {
      _checkAndSendExpiryNotifications();
    });

    // Sau đó chạy định kỳ mỗi 24 giờ
    _expiryCheckTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      _checkAndSendExpiryNotifications();
    });
    
    print('🕒 CronService: Đã khởi động tác vụ kiểm tra gia hạn tự động.');
  }

  void stop() {
    _expiryCheckTimer?.cancel();
  }

  Future<void> _checkAndSendExpiryNotifications() async {
    print('🕒 [${DateTime.now()}] Bắt đầu quét kiểm tra Membership sắp hết hạn...');
    try {
      final now = DateTime.now();
      // Tìm những người còn khoảng 3 ngày nữa hết hạn.
      final targetStart = now.add(const Duration(days: 3));
      final targetEnd = now.add(const Duration(days: 4));

      final userStatsResponse = await supabase
          .from('user_stats')
          .select('user_id, membership_expired_date')
          .gte('membership_expired_date', targetStart.toIso8601String())
          .lt('membership_expired_date', targetEnd.toIso8601String());

      if (userStatsResponse is List && userStatsResponse.isNotEmpty) {
        int count = 0;
        for (var stat in userStatsResponse) {
          final userId = stat['user_id'] as int;

          // Kiểm tra xem user này có bật thông báo hết hạn không
          final settingsRes = await supabase
              .from('notification_settings')
              .select('sub_expiry_notify')
              .eq('user_id', userId)
              .maybeSingle();

          if (settingsRes != null && settingsRes['sub_expiry_notify'] == 1) {
            // Đẩy thông báo
            await notificationService.createNotification({
              'user_id': userId,
              'type': 'membership_expiry',
              'title': 'Gói cước sắp hết hạn',
              'body': 'Gói Membership của bạn sẽ hết hạn trong khoảng 3 ngày tới. Vui lòng gia hạn để không bị gián đoạn trải nghiệm nhé!',
              'is_read': 0,
            });
            count++;
          }
        }
        print('✅ Đã gửi $count thông báo sắp hết hạn.');
      } else {
        print('✅ Không có User nào sắp hết hạn trong 3 ngày tới.');
      }
    } catch (e) {
      print('❌ Lỗi khi chạy CronService (Expiry Notification): $e');
    }
  }
}
