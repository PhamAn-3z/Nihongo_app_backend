import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  final String _smtpEmail;
  final String _smtpPassword;

  EmailService(this._smtpEmail, this._smtpPassword) {
    if (_smtpEmail.isEmpty || _smtpPassword.isEmpty) {
      print('⚠️ CẢNH BÁO: SMTP_EMAIL hoặc SMTP_PASSWORD bị trống. OTP sẽ không thể gửi đi.');
    }
  }

  Future<void> sendVerificationOtp(String recipientEmail, String otp) async {
    final smtpServer = gmail(_smtpEmail, _smtpPassword);

    final message = Message()
      ..from = Address(_smtpEmail, 'Nihongo App')
      ..recipients.add(recipientEmail)
      ..subject = 'Verify Your Account'
      ..html = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
          <h2 style="color: #333; text-align: center;">Verify Your Account</h2>
          <p style="font-size: 16px; color: #555;">Xin chào,</p>
          <p style="font-size: 16px; color: #555;">Mã OTP của bạn là:</p>
          <div style="text-align: center; margin: 30px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #007bff; padding: 10px 20px; border: 2px dashed #007bff; border-radius: 5px;">$otp</span>
          </div>
          <p style="font-size: 14px; color: #888; text-align: center;">Mã này sẽ hết hạn trong vòng 5 phút.</p>
        </div>
      ''';

    try {
      await send(message, smtpServer);
      print('✅ OTP đã được gửi tới: \$recipientEmail');
    } on MailerException catch (e) {
      print('❌ Lỗi gửi mail tới \$recipientEmail: \$e');
      rethrow;
    }
  }
}
