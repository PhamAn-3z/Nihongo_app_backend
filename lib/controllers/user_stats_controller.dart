import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/user_stats_service.dart';

class UserStatsController {
  final UserStatsService userStatsService;

  UserStatsController(this.userStatsService);

  Future<Response> get(Request request, String userId) async {
    try {
      final id = int.tryParse(userId);
      if (id == null) return Response.badRequest(body: jsonEncode({'message': 'Invalid User ID'}));
      final stats = await userStatsService.getStats(id);
      if (stats == null) return Response.notFound(jsonEncode({'message': 'Stats not found'}));
      return Response.ok(jsonEncode({'status': 'success', 'data': stats}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> update(Request request, String userId) async {
    try {
      final id = int.tryParse(userId);
      if (id == null) return Response.badRequest(body: jsonEncode({'message': 'Invalid User ID'}));
      final updates = jsonDecode(await request.readAsString());
      final stats = await userStatsService.updateStats(id, updates);
      return Response.ok(jsonEncode({'status': 'success', 'data': stats}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }
}
