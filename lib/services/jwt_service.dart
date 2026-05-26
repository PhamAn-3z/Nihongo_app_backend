import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtService {
  static const _secretKey = 'SUPER_SECRET_KEY';

  static String generateToken({
    required String userId,
    required String email,
  }) {
    final jwt = JWT({
      'userId': userId,
      'email': email,
    });

    return jwt.sign(
      SecretKey(_secretKey),
      expiresIn: const Duration(days: 7),
    );
  }

  static JWT verifyToken(String token) {
    return JWT.verify(token, SecretKey(_secretKey));
  }
}