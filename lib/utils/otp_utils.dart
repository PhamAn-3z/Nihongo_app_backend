import 'dart:math';

class OtpUtils {
  static String generateOtp({int length = 6}) {
    final random = Random();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(random.nextInt(10));
    }
    return buffer.toString();
  }
}
