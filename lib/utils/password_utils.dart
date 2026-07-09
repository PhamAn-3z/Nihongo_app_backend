import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordUtils {
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Kiểm tra mật khẩu mạnh: ít nhất 8 ký tự, có ít nhất một số và một chữ in hoa
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    return true;
  }
}
