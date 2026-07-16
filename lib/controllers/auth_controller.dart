import 'dart:convert';
import 'package:shelf/shelf.dart';

import '../services/auth_service.dart';
import '../utils/password_utils.dart';

class AuthController {
  final AuthService authService;

  AuthController(this.authService);

  Future<Response> login(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final email = data['email'];
      final password = data['password'];

      if (email == null || password == null) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Email and password are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = await authService.login(
        email: email,
        password: password,
      );

      if (token == null) {
        return Response(
          401,
          body: jsonEncode({
            'message': 'Invalid email or password',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'token': token,
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      // Trả về 403 nếu lỗi liên quan đến việc chưa xác thực email
      return Response(
        errorMsg.contains('verify your email') ? 403 : 500,
        body: jsonEncode({
          'message': errorMsg,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> register(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final email = data['email'];
      final password = data['password'];
      final confirmedPassword = data['confirmed_password'];
      final username = data['username'];

      // 1. Kiểm tra các trường bắt buộc
      if (email == null || password == null || confirmedPassword == null || username == null) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Email, password, confirmed_password, and username are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 2. Kiểm tra mật khẩu trùng khớp
      if (password != confirmedPassword) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Passwords do not match'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 3. Kiểm tra độ mạnh mật khẩu (>=8 ký tự, có số, có chữ in hoa)
      if (!PasswordUtils.isStrongPassword(password)) {
        return Response.badRequest(
          body: jsonEncode({
            'message': 'Password must be at least 8 characters long, include at least one number and one uppercase letter'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final user = await authService.register(
        email: email,
        password: password,
        username: username,
      );

      return Response.ok(
        jsonEncode({
          'message': 'User registered successfully. Please check your email for verification OTP.',
          'user': {
            'id': user?['user_id'],
            'email': user?['email'],
            'username': user?['username'],
          },
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      // Trả về 400 nếu lỗi liên quan đến việc trùng lặp dữ liệu
      final isBadRequest = errorMsg.contains('already exists');
      
      return Response(
        isBadRequest ? 400 : 500,
        body: jsonEncode({
          'message': errorMsg,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> verifyOtp(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final email = data['email'];
      final otp = data['otp'];

      if (email == null || otp == null) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Email and OTP are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await authService.verifyOtp(email: email, otp: otp);

      return Response.ok(
        jsonEncode({'message': 'Email verified successfully. You can now login.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({
          'message': e.toString().replaceAll('Exception: ', ''),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> resendOtp(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final email = data['email'];

      if (email == null) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Email is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await authService.resendOtp(email);

      return Response.ok(
        jsonEncode({'message': 'Verification OTP resent to your email.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({
          'message': e.toString().replaceAll('Exception: ', ''),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> forgotPassword(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final email = data['email'];

      if (email == null) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Email is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await authService.forgotPassword(email);

      return Response.ok(
        jsonEncode({'message': 'Password reset OTP has been sent to your email.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'message': e.toString().replaceAll('Exception: ', '')}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> resetPassword(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      final email = data['email'];
      final otp = data['otp'];
      final newPassword = data['new_password'];
      final confirmedPassword = data['confirmed_password'];

      if (email == null || otp == null || newPassword == null || confirmedPassword == null) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Email, OTP, new_password, and confirmed_password are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (newPassword != confirmedPassword) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Passwords do not match'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (!PasswordUtils.isStrongPassword(newPassword)) {
        return Response.badRequest(
          body: jsonEncode({
            'message': 'Password must be at least 8 characters long, include at least one number and one uppercase letter'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await authService.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );

      return Response.ok(
        jsonEncode({'message': 'Password has been reset successfully.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'message': e.toString().replaceAll('Exception: ', '')}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> logout(Request request) async {
    return Response.ok(
      jsonEncode({'message': 'Logged out successfully'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
