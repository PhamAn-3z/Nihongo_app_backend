import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

class VnPayService {
  final String tmnCode = 'MZZV5KJR';
  final String hashKey = '0SARJ6THU4YHS695PTVTFHYKSIQ109N5';
  final String vnpUrl = 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';

  String createPaymentUrl({
    required double amount,
    required String orderInfo,
    required String txnRef,
    required String returnUrl,
    required String ipAddr,
  }) {
    final createDate = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    
    Map<String, String> params = {
      "vnp_Version": "2.1.0",
      "vnp_Command": "pay",
      "vnp_TmnCode": tmnCode,
      "vnp_Amount": (amount * 100).toInt().toString(),
      "vnp_CreateDate": createDate,
      "vnp_CurrCode": "VND",
      "vnp_IpAddr": ipAddr,
      "vnp_Locale": "vn",
      "vnp_OrderInfo": orderInfo,
      "vnp_OrderType": "other",
      "vnp_ReturnUrl": returnUrl,
      "vnp_TxnRef": txnRef,
    };

    // 1. Sắp xếp params theo alphabet
    var sortedKeys = params.keys.toList()..sort();
    
    // 2. Tạo chuỗi query (Dùng Uri.encodeQueryComponent để mã hóa khoảng trắng thành '+')
    String queryString = sortedKeys.map((key) {
      return "${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(params[key]!)}";
    }).join("&");

    // 3. Tạo HMAC-SHA512 từ chuỗi query
    var keyBytes = utf8.encode(hashKey);
    var dataBytes = utf8.encode(queryString);
    var hmacSha512 = Hmac(sha512, keyBytes);
    var hashValue = hmacSha512.convert(dataBytes).toString();

    // 4. Trả về URL hoàn chỉnh
    return "$vnpUrl?$queryString&vnp_SecureHash=$hashValue";
  }

  bool verifyHash(Map<String, String> params) {
    final vnpSecureHash = params['vnp_SecureHash'];
    if (vnpSecureHash == null) return false;

    // Lấy các params dữ liệu, loại bỏ hash
    final dataParams = Map<String, String>.from(params)
      ..remove('vnp_SecureHash')
      ..remove('vnp_SecureHashType');

    // Sắp xếp
    var sortedKeys = dataParams.keys.toList()..sort();
    
    // Build lại chuỗi data để kiểm tra chữ ký
    // Lưu ý: Các giá trị nhận về từ request thường đã được decode, 
    // nên cần encode lại đúng chuẩn để khớp với chữ ký VNPay gửi sang.
    String queryString = sortedKeys.map((key) {
      return "${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(dataParams[key]!)}";
    }).join("&");

    var keyBytes = utf8.encode(hashKey);
    var dataBytes = utf8.encode(queryString);
    var hmacSha512 = Hmac(sha512, keyBytes);
    var hashValue = hmacSha512.convert(dataBytes).toString();

    return hashValue.toLowerCase() == vnpSecureHash.toLowerCase();
  }
}
