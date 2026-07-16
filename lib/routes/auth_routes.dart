import 'package:shelf_router/shelf_router.dart';
import '../controllers/auth_controller.dart';

Router authRoutes(AuthController controller) {
  final router = Router();

  // API Đăng nhập: POST /api/v1/auth/login
  router.post('/login', controller.login);
  
  // API Đăng ký: POST /api/v1/auth/register
  router.post('/register', controller.register);

  // API Xác thực OTP: POST /api/v1/auth/verify-otp
  router.post('/verify-otp', controller.verifyOtp);

  // API Gửi lại OTP: POST /api/v1/auth/resend-otp
  router.post('/resend-otp', controller.resendOtp);

  // API Quên mật khẩu: POST /api/v1/auth/forgot-password
  router.post('/forgot-password', controller.forgotPassword);

  // API Đặt lại mật khẩu: POST /api/v1/auth/reset-password
  router.post('/reset-password', controller.resetPassword);

  // API Đăng xuất: POST /api/v1/auth/logout
  router.post('/logout', controller.logout);

  return router;
}
