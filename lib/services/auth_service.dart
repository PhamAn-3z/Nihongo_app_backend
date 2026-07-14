import '../repositories/user_repository.dart';
import '../repositories/user_stats_repository.dart';
import '../repositories/email_verification_repository.dart';
import '../services/jwt_service.dart';
import '../services/email_service.dart';
import '../services/moderation_service.dart';
import '../utils/password_utils.dart';
import '../utils/otp_utils.dart';

class AuthService {
  final UserRepository userRepository;
  final UserStatsRepository userStatsRepository;
  final EmailVerificationRepository emailVerificationRepository;
  final EmailService emailService;
  final ModerationService moderationService; // Thêm ModerationService

  AuthService({
    required this.userRepository,
    required this.userStatsRepository,
    required this.emailVerificationRepository,
    required this.emailService,
    required this.moderationService,
  });

  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final existingUserByEmail = await userRepository.findByEmail(email);
    if (existingUserByEmail != null) {
      throw Exception('Email already exists');
    }

    final existingUserByUsername = await userRepository.findByUsername(username);
    if (existingUserByUsername != null) {
      throw Exception('Username already exists');
    }

    final hashedPassword = PasswordUtils.hashPassword(password);

    final newUser = await userRepository.createUser({
      'email': email,
      'password_hash': hashedPassword,
      'username': username,
      'created_at': DateTime.now().toIso8601String(),
      'email_verified': false,
      'status': 'active', // Mặc định là active
    });

    final userId = newUser?['user_id'];
    if (userId == null) throw Exception('Failed to create user');

    final intUserId = int.parse(userId.toString());

    await userStatsRepository.createUserStats({
      'user_id': intUserId,
      'current_streak': 0,
      'max_streak': 0,
      'total_exp': 0,
      'membership_id': 1,
      'is_active': true,
      'last_study_date': null,
      'membership_expired_date': null,
    });

    final otp = OtpUtils.generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

    await emailVerificationRepository.createVerification(
      userId: intUserId,
      otpCode: otp,
      expiresAt: expiresAt,
    );

    try {
      await emailService.sendVerificationOtp(email, otp);
    } catch (e) {
      print('❌ Lỗi gửi email cho $email: $e');
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

    final userId = int.parse(user['user_id'].toString());

    // --- KIỂM TRA TRẠNG THÁI BAN ---
    final banMessage = await moderationService.checkUserAccess(userId);
    if (banMessage != null) {
      throw Exception(banMessage);
    }
    // -------------------------------

    final token = JwtService.generateToken(
      userId: user['user_id'].toString(),
      email: user['email'],
      roleId: user['role_id'].toString(),
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

    final userId = int.parse(user['user_id'].toString());

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

    final userId = int.parse(user['user_id'].toString());
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
