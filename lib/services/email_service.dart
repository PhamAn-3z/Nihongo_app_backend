import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  final String smtpEmail;
  final String smtpPassword;

  EmailService(this.smtpEmail, this.smtpPassword);

  Future<void> sendVerificationOtp(String email, String otp) async {
    // Cấu hình SMTP (Ví dụ dùng Gmail)
    final smtpServer = gmail(smtpEmail, smtpPassword);

    final message = Message()
      ..from = Address(smtpEmail, 'NihonGo! App')
      ..recipients.add(email)
      ..subject = 'Xác thực tài khoản của bạn'
      ..text = 'Mã OTP của bạn là: $otp. Mã có hiệu lực trong 5 phút.';

    try {
      await send(message, smtpServer);
      print('✅ Đã gửi OTP đến $email');
    } catch (e) {
      print('❌ Lỗi gửi email: $e');
      throw Exception('Could not send verification email');
    }
  }
}
