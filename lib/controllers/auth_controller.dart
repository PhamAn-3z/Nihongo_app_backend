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
      return Response.internalServerError(
        body: jsonEncode({
          'message': e.toString(),
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
          'message': 'User registered successfully',
          'user': {
            'id': user?['user_id'], // Đổi từ 'id' sang 'user_id' để khớp với Supabase
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
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
