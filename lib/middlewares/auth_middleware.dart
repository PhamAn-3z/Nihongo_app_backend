import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../services/jwt_service.dart';

Middleware authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader =
      request.headers['Authorization'];

      if (authHeader == null ||
          !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(
          jsonEncode({
            'message': 'Missing token',
          }),
        );
      }

      try {
        final token =
        authHeader.replaceFirst('Bearer ', '');

        JwtService.verifyToken(token);

        return await innerHandler(request);
      } catch (e) {
        return Response.forbidden(
          jsonEncode({
            'message': 'Invalid token',
          }),
        );
      }
    };
  };
}