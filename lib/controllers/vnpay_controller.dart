import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import '../services/vnpay_service.dart';
import '../services/receipt_service.dart';

class VnPayController {
  final VnPayService vnpayService;
  final ReceiptService receiptService;

  VnPayController(this.vnpayService, this.receiptService);

  Future<Response> createPayment(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      Map<String, dynamic> receipt;
      
      // If receiptId is provided, use existing receipt. Otherwise, create a new one.
      if (data['receiptId'] != null) {
        final id = int.tryParse(data['receiptId'].toString());
        if (id == null) throw Exception('Invalid receiptId');
        
        final existingReceipt = await receiptService.getById(id);
        if (existingReceipt == null) throw Exception('Receipt not found');
        receipt = existingReceipt;
      } else {
        // Create a new receipt
        receipt = await receiptService.createReceipt(data);
      }

      final receiptId = receipt['id'].toString();
      final double total = (receipt['total'] as num).toDouble();

      // 2. Get IP Address
      String ipAddr = '127.0.0.1';
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      if (connectionInfo != null) {
        ipAddr = connectionInfo.remoteAddress.address;
      }

      // 3. Generate VNPay URL
      final returnUrl = data['returnUrl'] ?? 'http://localhost:8080/api/v1/vnpay/return';
      
      final paymentUrl = vnpayService.createPaymentUrl(
        amount: total, // Using the receipt total
        orderInfo: 'Thanh toan don hang #$receiptId',
        txnRef: receiptId,
        returnUrl: returnUrl,
        ipAddr: ipAddr,
      );

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'data': {
            'paymentUrl': paymentUrl,
            'receiptId': receiptId,
            'total': total
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> vnpayReturn(Request request) async {
    try {
      final params = request.url.queryParameters;
      
      if (!vnpayService.verifyHash(params)) {
        return Response.forbidden(
          jsonEncode({'status': 'error', 'message': 'Invalid signature'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final vnpResponseCode = params['vnp_ResponseCode'];
      final receiptId = int.tryParse(params['vnp_TxnRef'] ?? '');

      if (vnpResponseCode == '00' && receiptId != null) {
        // Payment successful
        await receiptService.markAsPaid(receiptId);
        return Response.ok(
          jsonEncode({'status': 'success', 'message': 'Payment successful', 'receiptId': receiptId}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.ok(
          jsonEncode({'status': 'fail', 'message': 'Payment failed or cancelled', 'code': vnpResponseCode}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'status': 'error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // IPN is for server-to-server notification
  Future<Response> vnpayIpn(Request request) async {
    try {
      final params = request.url.queryParameters;
      
      if (!vnpayService.verifyHash(params)) {
        return Response.ok(jsonEncode({'RspCode': '97', 'Message': 'Invalid signature'}));
      }

      final vnpResponseCode = params['vnp_ResponseCode'];
      final receiptId = int.tryParse(params['vnp_TxnRef'] ?? '');

      if (receiptId == null) {
        return Response.ok(jsonEncode({'RspCode': '01', 'Message': 'Order not found'}));
      }

      if (vnpResponseCode == '00') {
        await receiptService.markAsPaid(receiptId);
      }

      return Response.ok(jsonEncode({'RspCode': '00', 'Message': 'Confirm Success'}));
    } catch (e) {
      return Response.ok(jsonEncode({'RspCode': '99', 'Message': 'Unknown error'}));
    }
  }
}
