import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/jwt_service.dart';
import '../services/moderation_service.dart';

Middleware authMiddleware(ModerationService moderationService) {
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
        final payload = jwt.payload as Map<String, dynamic>;
        final userId = int.parse(payload['userId'].toString());

        // --- KIỂM TRA TRẠNG THÁI BAN REAL-TIME ---
        final banMessage = await moderationService.checkUserAccess(userId);
        if (banMessage != null) {
          return Response(
            403,
            body: jsonEncode({'message': banMessage}),
            headers: {'content-type': 'application/json'},
          );
        }
        // ------------------------------------------

        // Merge existing context to preserve routing segments
        final updatedRequest = request.change(
          context: Map<String, Object?>.from(request.context)..['authPayload'] = payload,
        );

        return await innerHandler(updatedRequest);
      } catch (e) {
        return Response.forbidden(
          jsonEncode({'message': 'Invalid or expired token'}),
          headers: {'content-type': 'application/json'},
        );
      }
    };
  };
}
