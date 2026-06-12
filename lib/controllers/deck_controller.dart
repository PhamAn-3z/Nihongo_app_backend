import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/deck_service.dart';

class DeckController {
  final DeckService _deckService;

  DeckController(this._deckService);

  Future<Response> bulkImportCreateDeck(Request request) async {
    try {
      final payload = request.context['authPayload'] as Map<String, dynamic>?;
      if (payload == null || payload['userId'] == null) {
        return Response.forbidden(jsonEncode({'message': 'Unauthorized'}));
      }
      
      final dynamic userId = payload['userId'];
      final body = jsonDecode(await request.readAsString());

      final String deckTitle = body['deckTitle'];
      final String publicStatus = body['publicStatus'] ?? 'private';
      final int? parentId = body['parentId'];
      final List<dynamic> headers = body['headers'];
      final List<dynamic> rows = body['rows'];

      final result = await _deckService.bulkImportCreateDeck(
        userId: userId,
        title: deckTitle,
        publicStatus: publicStatus,
        parentId: parentId,
        headers: headers.cast<Map<String, dynamic>>(),
        rows: rows.cast<Map<String, dynamic>>(),
      );

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Khởi tạo bộ đề và cấu hình lộ trình học cá nhân hóa thành công!",
          "data": result
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"success": false, "message": e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> getAllDecks(Request request) async {
    try {
      final decks = await _deckService.getAllDecks();
      return Response.ok(
        jsonEncode({"success": true, "data": decks}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"success": false, "message": e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> getUserDecksTree(Request request) async {
    try {
      final payload = request.context['authPayload'] as Map<String, dynamic>?;
      if (payload == null || payload['userId'] == null) {
        return Response.forbidden(jsonEncode({'message': 'Unauthorized'}));
      }

      final dynamic userId = payload['userId'];
      final tree = await _deckService.getUserDecksTree(userId);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Lấy danh sách cây bộ đề Anki thành công!",
          "data": tree
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"success": false, "message": e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> getDeckStudyData(Request request) async {
    try {
      final payload = request.context['authPayload'] as Map<String, dynamic>?;
      if (payload == null || payload['userId'] == null) {
        return Response.forbidden(jsonEncode({'message': 'Unauthorized'}));
      }

      final dynamic userId = payload['userId'];
      final String? deckIdStr = request.params['id'];
      
      if (deckIdStr == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Missing deck ID'}));
      }

      final int deckId = int.parse(deckIdStr);
      final data = await _deckService.getDeckStudyData(deckId, userId);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Tải dữ liệu học tập của bộ đề thành công!",
          "data": data
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"success": false, "message": e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> deleteDeck(Request request) async {
    try {
      final payload = request.context['authPayload'] as Map<String, dynamic>?;
      if (payload == null || payload['userId'] == null) {
        return Response.forbidden(jsonEncode({'message': 'Unauthorized'}));
      }

      final dynamic userId = payload['userId'];
      final String? deckIdStr = request.params['id'];

      if (deckIdStr == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Missing deck ID'}));
      }

      final int deckId = int.parse(deckIdStr);
      await _deckService.deleteDeck(deckId, userId);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Xóa bộ đề vĩnh viễn thành công!"
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({"success": false, "message": e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
