import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordUtils {
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Kiểm tra mật khẩu mạnh: ít nhất 8 ký tự, có chữ thường, chữ hoa và số
  static bool isStrongPassword(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
    return regex.hasMatch(password);
  }
}
