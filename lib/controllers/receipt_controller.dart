import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/receipt_service.dart';

class ReceiptController {
  final ReceiptService receiptService;

  ReceiptController(this.receiptService);

  Future<Response> getByUserId(Request request, String userId) async {
    try {
      final id = int.tryParse(userId);
      if (id == null) return Response.badRequest(body: jsonEncode({'message': 'Invalid User ID'}));
      final receipts = await receiptService.getByUserId(id);
      return Response.ok(jsonEncode({'status': 'success', 'data': receipts}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> getMyReceipts(Request request) async {
    try {
      final payload = request.context['authPayload'] as Map<String, dynamic>?;
      if (payload == null) {
        return Response.forbidden(jsonEncode({'status': 'error', 'message': 'Unauthorized'}));
      }

      final userId = int.tryParse(payload['userId']?.toString() ?? '');
      if (userId == null) {
        return Response.badRequest(body: jsonEncode({'status': 'error', 'message': 'Invalid User ID in token'}));
      }

      final receipts = await receiptService.getByUserId(userId);
      return Response.ok(
        jsonEncode({'status': 'success', 'data': receipts}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> create(Request request) async {
    try {
      final data = jsonDecode(await request.readAsString());
      final receipt = await receiptService.createReceipt(data);
      return Response.ok(jsonEncode({'status': 'success', 'data': receipt}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.badRequest(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> pay(Request request, String id) async {
    try {
      final receiptId = int.tryParse(id);
      if (receiptId == null) return Response.badRequest(body: jsonEncode({'message': 'Invalid ID'}));
      final receipt = await receiptService.markAsPaid(receiptId);
      return Response.ok(jsonEncode({'status': 'success', 'data': receipt}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> update(Request request, String id) async {
    try {
      final receiptId = int.tryParse(id);
      if (receiptId == null) return Response.badRequest(body: jsonEncode({'message': 'Invalid ID'}));
      final data = jsonDecode(await request.readAsString());
      final receipt = await receiptService.update(receiptId, data);
      return Response.ok(jsonEncode({'status': 'success', 'data': receipt}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.badRequest(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> cleanup(Request request) async {
    try {
      await receiptService.cleanupExpiredReceipts();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Expired unpaid receipts deleted'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  }
}
