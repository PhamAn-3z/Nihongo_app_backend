import '../repositories/user_repository.dart';
import '../services/jwt_service.dart';
import '../utils/password_utils.dart';

class AuthService {
  final UserRepository userRepository;

  AuthService(this.userRepository);

  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String username,
  }) async {
    // Kiểm tra xem email đã tồn tại chưa
    final existingUser = await userRepository.findByEmail(email);
    if (existingUser != null) {
      throw Exception('Email already exists');
    }

    // Mã hóa mật khẩu
    final hashedPassword = PasswordUtils.hashPassword(password);

    // Lưu user vào DB - Sử dụng 'password_hash' và 'username' khớp với Supabase
    final newUser = await userRepository.createUser({
      'email': email,
      'password_hash': hashedPassword,
      'username': username,
      'created_at': DateTime.now().toIso8601String(),
    });

    return newUser;
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final user = await userRepository.findByEmail(email);

    if (user == null) {
      return null;
    }

    final hashedPassword = PasswordUtils.hashPassword(password);

    // So sánh mật khẩu đã hash - Sử dụng 'password_hash' khớp với DB
    if (hashedPassword != user['password_hash']) {
      return null;
    }

    // Tạo JWT token - Đổi từ 'id' sang 'user_id'
    final token = JwtService.generateToken(
      userId: user['user_id'].toString(),
      email: user['email'],
    );

    return token;
  }
}
