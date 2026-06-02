import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/jwt_service.dart';

Middleware authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['Authorization'];

      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(
          jsonEncode({'message': 'Missing token'}),
          headers: {'content-type': 'application/json'},
        );
      }

      try {
        final token = authHeader.replaceFirst('Bearer ', '');
        final jwt = JwtService.verifyToken(token);

        // Lưu thông tin từ JWT vào context của request để Controller có thể sử dụng
        final updatedRequest = request.change(context: {'authPayload': jwt.payload});

        return await innerHandler(updatedRequest);
      } catch (e) {
        return Response.forbidden(
          jsonEncode({'message': 'Invalid token'}),
          headers: {'content-type': 'application/json'},
        );
      }
    };
  };
}
