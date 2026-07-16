import 'dart:async';
import 'package:supabase/supabase.dart';
import '../services/notification_service.dart';

class CronService {
  final SupabaseClient supabase;
  final NotificationService notificationService;
  Timer? _expiryCheckTimer;
  Timer? _studyReminderTimer;
  DateTime? _lastStudyReminderCheck;

  CronService(this.supabase, this.notificationService);

  void start() {
    // 1. Tác vụ kiểm tra Membership hết hạn (Chạy 24h một lần)
    // Chạy lần đầu sau 10 giây
    Timer(const Duration(seconds: 10), () {
      _checkAndSendExpiryNotifications();
    });
    _expiryCheckTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      _checkAndSendExpiryNotifications();
    });

    // 2. Tác vụ nhắc giờ học (Quét mỗi 5 phút)
    // Chạy lần đầu sau 20 giây
    Timer(const Duration(seconds: 20), () {
      _checkAndSendStudyReminders();
    });
    _studyReminderTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkAndSendStudyReminders();
    });
    
    print('🕒 CronService: Đã khởi động các tác vụ tự động (Hết hạn & Nhắc học).');
  }

  void stop() {
    _expiryCheckTimer?.cancel();
    _studyReminderTimer?.cancel();
  }

  Future<void> _checkAndSendStudyReminders() async {
    final now = DateTime.now();
    final dayOfWeek = now.weekday; // 1 = Thứ 2, 7 = Chủ nhật
    
    // Xác định khoảng thời gian cần kiểm tra
    final lastCheck = _lastStudyReminderCheck ?? now.subtract(const Duration(minutes: 5));
    _lastStudyReminderCheck = now;

    print('🕒 [${now}] Quét nhắc hẹn học tập...');

    try {
      // Lấy danh sách các cài đặt nhắc nhở đang bật
      final settingsResponse = await supabase
          .from('notification_settings')
          .select('user_id, study_reminder_time, study_reminder_days')
          .eq('study_reminder', 1);

      if (settingsResponse is List && settingsResponse.isNotEmpty) {
        int count = 0;
        for (var setting in settingsResponse) {
          try {
            final userId = setting['user_id'] as int;
            final reminderTimeStr = setting['study_reminder_time'] as String; // Định dạng "HH:mm"
            final reminderDays = List<int>.from(setting['study_reminder_days'] ?? []);

            // Kiểm tra xem hôm nay có trong lịch nhắc không
            if (!reminderDays.contains(dayOfWeek)) continue;

            // Chuyển "HH:mm" thành DateTime của ngày hôm nay
            final timeParts = reminderTimeStr.split(':');
            if (timeParts.length != 2) continue;
            
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            final reminderTimeToday = DateTime(now.year, now.month, now.day, hour, minute);

            // Kiểm tra nếu thời điểm nhắc nhở nằm trong khoảng thời gian quét (lastCheck < reminder <= now)
            if (reminderTimeToday.isAfter(lastCheck) && 
               (reminderTimeToday.isBefore(now) || reminderTimeToday.isAtSameMomentAs(now))) {
              
              await notificationService.createNotification({
                'user_id': userId,
                'type': 'study_reminder',
                'title': 'Đến giờ học rồi! 📚',
                'body': 'Đã đến giờ ôn tập tiếng Nhật như bạn đã hẹn. Cùng dành ra ít phút nhé!',
                'is_read': 0,
              });
              count++;
            }
          } catch (e) {
            print('⚠️ Lỗi xử lý nhắc nhở cho user: ${setting['user_id']} - $e');
          }
        }
        if (count > 0) print('✅ Đã gửi $count thông báo nhắc học.');
      }
    } catch (e) {
      print('❌ Lỗi khi chạy CronService (Study Reminder): $e');
    }
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
        print('✅ Đã gửi $count thông báo sắp hết hạn.')
      } else {
        print('✅ Không có User nào sắp hết hạn trong 3 ngày tới.');
      }
    } catch (e) {
      print('❌ Lỗi khi chạy CronService (Expiry Notification): $e');
    }
  }
}
