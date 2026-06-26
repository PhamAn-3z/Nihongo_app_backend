import '../repositories/user_repository.dart';
import '../repositories/email_verification_repository.dart';
import '../services/jwt_service.dart';
import '../services/email_service.dart';
import '../utils/password_utils.dart';
import '../utils/otp_utils.dart';

class AuthService {
  final UserRepository userRepository;
  final EmailVerificationRepository emailVerificationRepository;
  final EmailService emailService;

  AuthService({
    required this.userRepository,
    required this.emailVerificationRepository,
    required this.emailService,
  });

  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String username,
  }) async {
    // 1. Kiểm tra xem email đã tồn tại chưa
    final existingUserByEmail = await userRepository.findByEmail(email);
    if (existingUserByEmail != null) {
      throw Exception('Email already exists');
    }

    // 2. Kiểm tra xem username đã tồn tại chưa
    final existingUserByUsername = await userRepository.findByUsername(username);
    if (existingUserByUsername != null) {
      throw Exception('Username already exists');
    }

    // 3. Mã hóa mật khẩu
    final hashedPassword = PasswordUtils.hashPassword(password);

    // 4. Lưu user vào DB
    final newUser = await userRepository.createUser({
      'email': email,
      'password_hash': hashedPassword,
      'username': username,
      'created_at': DateTime.now().toIso8601String(),
      'email_verified': false,
    });

    final userId = newUser['user_id'] as int;

    // 5. Tạo mã OTP
    final otp = OtpUtils.generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

    // 6. Lưu OTP vào bảng email_verifications
    await emailVerificationRepository.createVerification(
      userId: userId,
      otpCode: otp,
      expiresAt: expiresAt,
    );

    // 7. Gửi email OTP
    try {
      await emailService.sendVerificationOtp(email, otp);
    } catch (e) {
      print('❌ Lỗi gửi email cho $email: $e');
      // Bạn có thể chọn ném lỗi hoặc không tùy vào luồng nghiệp vụ
    }

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

    if (user['email_verified'] == false) {
      throw Exception('Please verify your email first');
    }

    final hashedPassword = PasswordUtils.hashPassword(password);

    if (hashedPassword != user['password_hash']) {
      return null;
    }

    final token = JwtService.generateToken(
      userId: user['user_id'].toString(),
      email: user['email'],
    );

    return token;
  }

  Future<void> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final user = await userRepository.findByEmail(email);
    if (user == null) {
      throw Exception('User not found');
    }

    final userId = user['user_id'] as int;

    final verification = await emailVerificationRepository.findLatestByUserId(userId);
    if (verification == null) {
      throw Exception('No verification code found');
    }

    if (verification['verified'] == true) {
      throw Exception('This code has already been verified');
    }

    final expiresAt = DateTime.parse(verification['expires_at']);
    if (expiresAt.isBefore(DateTime.now())) {
      throw Exception('OTP has expired');
    }

    if (verification['otp_code'] != otp) {
      throw Exception('Invalid OTP code');
    }

    await userRepository.markEmailAsVerified(userId);
    await emailVerificationRepository.markAsVerified(verification['id']);
  }

  Future<void> resendOtp(String email) async {
    final user = await userRepository.findByEmail(email);
    if (user == null) {
      throw Exception('User not found');
    }

    if (user['email_verified'] == true) {
      throw Exception('Email already verified');
    }

    final userId = user['user_id'] as int;
    final otp = OtpUtils.generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

    await emailVerificationRepository.createVerification(
      userId: userId,
      otpCode: otp,
      expiresAt: expiresAt,
    );

    await emailService.sendVerificationOtp(email, otp);
  }
}
