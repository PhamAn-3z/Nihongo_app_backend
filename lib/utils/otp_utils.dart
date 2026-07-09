import 'dart:math';

class OtpUtils {
  /// Tạo mã OTP ngẫu nhiên gồm 6 chữ số
  static String generateOtp() {
    final random = Random();
    final otp = List.generate(6, (index) => random.nextInt(10)).join();
    return otp;
  }
}
