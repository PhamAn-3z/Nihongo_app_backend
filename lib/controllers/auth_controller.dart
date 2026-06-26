import 'dart:convert';
import 'package:shelf/shelf.dart';

import '../services/auth_service.dart';

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
        return Response.forbidden(
          jsonEncode({
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
      return Response(
        e.toString().contains('verify your email') ? 403 : 500,
        body: jsonEncode({
          'message': e.toString().replaceAll('Exception: ', ''),
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
      final username = data['username'];

      if (email == null || password == null || username == null) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Email, password, and username are required'}),
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
      return Response.internalServerError(
        body: jsonEncode({
          'message': e.toString().replaceAll('Exception: ', ''),
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

  Future<Response> logout(Request request) async {
    return Response.ok(
      jsonEncode({'message': 'Logged out successfully'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
