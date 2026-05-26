import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordUtils {
  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}