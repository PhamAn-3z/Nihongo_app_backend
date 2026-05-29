import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import '../lib/services/vnpay_service.dart';

void main() {
  final port = '8081'; // Use a different port for testing
  final host = 'http://localhost:$port';
  late Process p;

  final tmnCode = '76T89WML';
  final hashSecret = 'X0C1U3Z2K5N4P7R9J8H1G0F2D4S6A8O1';
  final vnpUrl = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';
  final returnUrl = 'http://localhost:8080/api/v1/vnpay/vnpay_return';

  final vnpayService = VNPayService(
    tmnCode: tmnCode,
    hashSecret: hashSecret,
    vnpUrl: vnpUrl,
    returnUrl: returnUrl,
  );

  group('VNPayService Unit Tests', () {
    test('createPaymentUrl generates a valid URL with signature', () {
      final url = vnpayService.createPaymentUrl(
        orderId: '123',
        amount: 10000,
        orderInfo: 'Test Payment',
        ipAddress: '127.0.0.1',
        createDate: DateTime(2023, 1, 1, 12, 0, 0),
      );

      expect(url, contains('vnp_TmnCode=$tmnCode'));
      expect(url, contains('vnp_Amount=1000000'));
      expect(url, contains('vnp_TxnRef=123'));
      expect(url, contains('vnp_SecureHash='));
    });

    test('verifyHash returns true for valid signature', () {
      final params = {
        'vnp_Amount': '1000000',
        'vnp_Command': 'pay',
        'vnp_CreateDate': '20230101120000',
        'vnp_CurrCode': 'VND',
        'vnp_IpAddr': '127.0.0.1',
        'vnp_Locale': 'vn',
        'vnp_OrderInfo': 'Test Payment',
        'vnp_OrderType': 'other',
        'vnp_ReturnUrl': returnUrl,
        'vnp_TmnCode': tmnCode,
        'vnp_TxnRef': '123',
        'vnp_Version': '2.1.0',
      };

      // Manually sign
      var sortedKeys = params.keys.toList()..sort();
      var signData = sortedKeys
          .map((key) => '$key=${Uri.encodeQueryComponent(params[key]!)}')
          .join('&');
      
      var hmac = Hmac(sha512, utf8.encode(hashSecret));
      var signature = hmac.convert(utf8.encode(signData)).toString();

      params['vnp_SecureHash'] = signature;

      expect(vnpayService.verifyHash(params), isTrue);
    });

    test('verifyHash ignores non-vnp parameters and empty values', () {
      final params = {
        'vnp_Amount': '1000000',
        'vnp_Command': 'pay',
        'vnp_TmnCode': tmnCode,
        'other_param': 'ignore_me',
        'empty_param': '',
      };

      // Manually sign ONLY valid vnp_ params
      final signData = 'vnp_Amount=1000000&vnp_Command=pay&vnp_TmnCode=$tmnCode';
      
      var hmac = Hmac(sha512, utf8.encode(hashSecret));
      var signature = hmac.convert(utf8.encode(signData)).toString();

      params['vnp_SecureHash'] = signature;

      expect(vnpayService.verifyHash(params.cast<String, String>()), isTrue);
    });

    test('verifyHash returns false for invalid signature', () {
      final params = {
        'vnp_TxnRef': '123',
        'vnp_SecureHash': 'invalid_hash',
      };
      expect(vnpayService.verifyHash(params), isFalse);
    });
  });

  group('VNPay Integration Tests', () {
    setUpAll(() async {
      p = await Process.start(
        'dart',
        ['run', 'bin/server.dart'],
        environment: {'PORT': port},
      );
      
      // Pipe server output to current process for debugging
      p.stdout.transform(utf8.decoder).listen((data) => print('Server STDOUT: $data'));
      p.stderr.transform(utf8.decoder).listen((data) => print('Server STDERR: $data'));

      // Wait for server to start
      await Future.delayed(Duration(seconds: 5));
    });

    tearDownAll(() => p.kill());

    test('POST /api/v1/vnpay/create_payment_url returns success', () async {
      final response = await http.post(
        Uri.parse('$host/api/v1/vnpay/create_payment_url'),
        body: jsonEncode({
          'receipt_id': 123,
          'amount': 10000.0,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body);
      expect(data['status'], 'success');
      expect(data['payment_url'], contains('vnpayment.vn'));
    });

    test('GET /api/v1/vnpay/vnpay_return with invalid signature returns 400', () async {
      final response = await http.get(
        Uri.parse('$host/api/v1/vnpay/vnpay_return?vnp_SecureHash=invalid'),
      );

      expect(response.statusCode, 400);
      final data = jsonDecode(response.body);
      expect(data['message'], 'Invalid signature');
    });

    test('GET /api/v1/vnpay/vnpay_ipn with invalid signature returns RspCode 97', () async {
      final response = await http.get(
        Uri.parse('$host/api/v1/vnpay/vnpay_ipn?vnp_SecureHash=invalid'),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body);
      expect(data['RspCode'], '97');
    });
  });
}
