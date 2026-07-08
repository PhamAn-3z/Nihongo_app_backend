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

  Future<Response> getDeckComments(Request request) async {
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
      final comments = await _deckService.getDeckComments(deckId, userId);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Lấy danh sách bình luận thành công!",
          "data": comments
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

  Future<Response> addComment(Request request) async {
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
      final body = jsonDecode(await request.readAsString());
      
      final String content = body['content'] ?? '';
      final int? parentCommentId = body['parentCommentId'];

      final comment = await _deckService.addComment(
        deckId: deckId,
        userId: userId,
        parentCommentId: parentCommentId,
        content: content,
      );

      return Response(201, // Created
        body: jsonEncode({
          "success": true,
          "message": "Đã thêm bình luận thành công!",
          "data": comment
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      // Làm sạch thông báo lỗi để trả về cho Client
      final message = e.toString().contains('Exception: ') 
          ? e.toString().split('Exception: ')[1] 
          : e.toString();

      return Response(400,
        body: jsonEncode({"success": false, "message": message}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> deleteComment(Request request) async {
    try {
      final payload = request.context['authPayload'] as Map<String, dynamic>?;
      if (payload == null || payload['userId'] == null) {
        return Response.forbidden(jsonEncode({'message': 'Unauthorized'}));
      }

      final dynamic userId = payload['userId'];
      final String? commentIdStr = request.params['comment_id'];

      if (commentIdStr == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Missing comment ID'}));
      }

      final int commentId = int.parse(commentIdStr);
      await _deckService.deleteComment(commentId: commentId, userId: userId);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": "Xóa bình luận thành công!"
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('FORBIDDEN')) {
        return Response.forbidden(
          jsonEncode({"success": false, "message": "Bạn không có quyền xóa bình luận này!"}),
          headers: {'content-type': 'application/json'},
        );
      }
      
      final message = errorMsg.contains('Exception: ') 
          ? errorMsg.split('Exception: ')[1] 
          : errorMsg;

      return Response(404, // Not Found hoặc 400 tùy trường hợp, ở đây đa số là 404
        body: jsonEncode({"success": false, "message": message}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> toggleFavorite(Request request) async {
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

      // Đọc isFavorite từ body request
      final body = jsonDecode(await request.readAsString());
      final bool isFavorite = body['isFavorite'];

      final int deckId = int.parse(deckIdStr);
      await _deckService.setFavoriteStatus(deckId, userId, isFavorite);

      return Response.ok(
        jsonEncode({
          "success": true,
          "message": isFavorite ? "Đã thêm vào danh sách yêu thích!" : "Đã xóa khỏi danh sách yêu thích!",
          "data": { "isFavorite": isFavorite }
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      // Trả về lỗi 400 như tài liệu yêu cầu nếu bản ghi chưa tồn tại
      return Response(400,
        body: jsonEncode({
          "success": false, 
          "message": "Hành động không hợp lệ! Bạn phải lưu bộ đề này trước khi thay đổi trạng thái yêu thích."
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> getMembershipLimit(Request request) async {
    try {
      final payload = request.context['authPayload'] as Map<String, dynamic>?;
      if (payload == null || payload['userId'] == null) {
        return Response.forbidden(jsonEncode({'message': 'Unauthorized'}));
      }

      final dynamic userId = payload['userId'];
      final limitData = await _deckService.getUserMembershipLimit(userId);

      return Response.ok(
        jsonEncode({
          "success": true,
          "data": limitData
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
