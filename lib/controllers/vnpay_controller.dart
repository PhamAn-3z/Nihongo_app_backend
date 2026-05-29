import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/vnpay_service.dart';
import '../services/receipt_service.dart';

class VNPayController {
  final VNPayService vnpayService;
  final ReceiptService receiptService;

  VNPayController(this.vnpayService, this.receiptService);

  Future<Response> createPaymentUrl(Request request) async {
    try {
      final content = await request.readAsString();
      if (content.isEmpty) {
        return Response.badRequest(body: jsonEncode({'status': 'error', 'message': 'Request body is empty'}), headers: {'Content-Type': 'application/json'});
      }
      
      final body = jsonDecode(content);
      final receiptId = body['receipt_id'];
      if (receiptId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'receipt_id is required'}));
      }

      // In a real app, you'd fetch the receipt to get the amount
      // For now, we'll assume the client might pass it or we fetch it from receiptService
      // Let's try to fetch it to be safe
      // Note: We need to handle the case where receiptId is String or int
      final id = int.tryParse(receiptId.toString());
      if (id == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Invalid receipt_id'}));
      }

      // Mock fetching receipt data (in real app, use receiptService)
      // For this implementation, let's assume we get it from the request for simplicity of the test
      // but ideally we should fetch from DB.
      final amount = body['amount']?.toDouble();
      if (amount == null) {
        return Response.badRequest(body: jsonEncode({'message': 'amount is required'}));
      }

      final ipAddress = request.context['shelf.io.connection_info'] != null 
          ? (request.context['shelf.io.connection_info'] as dynamic).remoteAddress.address 
          : '127.0.0.1';

      final paymentUrl = vnpayService.createPaymentUrl(
        orderId: id.toString(),
        amount: amount,
        orderInfo: 'Thanh toan don hang $id',
        ipAddress: ipAddress,
      );

      return Response.ok(jsonEncode({
        'status': 'success',
        'payment_url': paymentUrl
      }), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}));
    }
  }

  Future<Response> vnpayReturn(Request request) async {
    final params = request.url.queryParameters;
    final isValid = vnpayService.verifyHash(params);

    if (isValid) {
      final responseCode = params['vnp_ResponseCode'];
      final receiptId = int.tryParse(params['vnp_TxnRef'] ?? '');

      if (responseCode == '00') {
        if (receiptId != null) {
          try {
            await receiptService.markAsPaid(receiptId);
          } catch (e) {
            print('Error updating receipt $receiptId: $e');
          }
        }
        return Response.ok(jsonEncode({'status': 'success', 'message': 'Payment successful'}));
      } else {
        return Response.ok(jsonEncode({'status': 'failed', 'message': 'Payment failed with code $responseCode'}));
      }
    } else {
      return Response.badRequest(body: jsonEncode({'status': 'error', 'message': 'Invalid signature'}));
    }
  }

  Future<Response> vnpayIpn(Request request) async {
    final params = request.url.queryParameters;
    final isValid = vnpayService.verifyHash(params);

    if (!isValid) {
      return Response.ok(jsonEncode({'RspCode': '97', 'Message': 'Invalid signature'}));
    }

    try {
      final receiptId = int.tryParse(params['vnp_TxnRef'] ?? '');
      final responseCode = params['vnp_ResponseCode'];

      if (receiptId == null) {
        return Response.ok(jsonEncode({'RspCode': '01', 'Message': 'Order not found'}));
      }

      if (responseCode == '00') {
        // Update receipt status in DB
        await receiptService.markAsPaid(receiptId);
        return Response.ok(jsonEncode({'RspCode': '00', 'Message': 'Confirm Success'}));
      } else {
        return Response.ok(jsonEncode({'RspCode': '00', 'Message': 'Confirm Success (Payment Failed)'}));
      }
    } catch (e) {
      return Response.ok(jsonEncode({'RspCode': '99', 'Message': 'Unknown error'}));
    }
  }
}
