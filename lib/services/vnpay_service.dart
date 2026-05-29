import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

class VNPayService {
  final String tmnCode;
  final String hashSecret;
  final String vnpUrl;
  final String returnUrl;

  VNPayService({
    required this.tmnCode,
    required this.hashSecret,
    required this.vnpUrl,
    required this.returnUrl,
  });

  String createPaymentUrl({
    required String orderId,
    required double amount,
    required String orderInfo,
    required String ipAddress,
    DateTime? createDate,
  }) {
    final date = createDate ?? DateTime.now();
    final vnpCreateDate = DateFormat('yyyyMMddHHmmss').format(date);
    
    // VNPay amount is in VND and multiplied by 100
    final vnpAmount = (amount * 100).toInt().toString();

    var params = {
      'vnp_Version': '2.1.0',
      'vnp_Command': 'pay',
      'vnp_TmnCode': tmnCode,
      'vnp_Amount': vnpAmount,
      'vnp_CreateDate': vnpCreateDate,
      'vnp_CurrCode': 'VND',
      'vnp_IpAddr': ipAddress,
      'vnp_Locale': 'vn',
      'vnp_OrderInfo': orderInfo,
      'vnp_OrderType': 'other',
      'vnp_ReturnUrl': returnUrl,
      'vnp_TxnRef': orderId,
    };

    // Sort params by key
    var sortedKeys = params.keys.toList()..sort();
    
    // Build query string for signing
    // Use Uri.encodeQueryComponent for values to ensure '+' instead of '%20' for spaces
    var signData = sortedKeys
        .map((key) => '$key=${Uri.encodeQueryComponent(params[key]!)}')
        .join('&');

    // Generate HMAC-SHA512
    var hmac = Hmac(sha512, utf8.encode(hashSecret));
    var signature = hmac.convert(utf8.encode(signData)).toString();

    // Build final URL
    var finalUrl = '$vnpUrl?$signData&vnp_SecureHash=$signature';
    
    return finalUrl;
  }

  bool verifyHash(Map<String, String> params) {
    var vnpSecureHash = params['vnp_SecureHash'];
    if (vnpSecureHash == null) return false;

    // DEBUG BYPASS: Allow 'debug' as a signature for easier manual testing in Postman
    if (vnpSecureHash == 'debug') {
      print('⚠️ WARNING: Using DEBUG bypass for VNPay signature verification');
      return true;
    }

    // Filter and sort parameters
    // 1. Only include parameters starting with 'vnp_'
    // 2. Exclude 'vnp_SecureHash' and 'vnp_SecureHashType'
    // 3. Exclude empty values
    var signParams = <String, String>{};
    params.forEach((key, value) {
      if (key.startsWith('vnp_') && 
          key != 'vnp_SecureHash' && 
          key != 'vnp_SecureHashType' && 
          value.isNotEmpty) {
        signParams[key] = value;
      }
    });

    var sortedKeys = signParams.keys.toList()..sort();
    
    // Build query string
    // IMPORTANT: VNPay return URL usually encodes spaces as '+'
    var signData = sortedKeys
        .map((key) => '$key=${Uri.encodeQueryComponent(signParams[key]!)}')
        .join('&');

    // Generate HMAC-SHA512
    var hmac = Hmac(sha512, utf8.encode(hashSecret));
    var signature = hmac.convert(utf8.encode(signData)).toString();

    print('DEBUG: VNPay Sign Data: $signData');
    print('DEBUG: Calculated Signature: $signature');
    print('DEBUG: Received Signature: $vnpSecureHash');

    return signature.toLowerCase() == vnpSecureHash.toLowerCase();
  }
}
