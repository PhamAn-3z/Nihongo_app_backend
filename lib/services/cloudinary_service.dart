import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  final String cloudName;
  final String apiKey;
  final String apiSecret;
  final String uploadPreset;

  CloudinaryService({
    required this.cloudName,
    required this.apiKey,
    required this.apiSecret,
    required this.uploadPreset,
  });

  Map<String, dynamic> generateUploadSignature() {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // Cloudinary yêu cầu các tham số trong signature phải theo thứ tự alphabet
    final params = {
      'timestamp': timestamp.toString(),
      'upload_preset': uploadPreset,
    };

    final sortedKeys = params.keys.toList()..sort();
    final paramString = sortedKeys.map((k) => '$k=${params[k]}').join('&');
    final stringToSign = '$paramString$apiSecret';

    final signature = sha1.convert(utf8.encode(stringToSign)).toString();

    return {
      'signature': signature,
      'timestamp': timestamp,
      'apiKey': apiKey,
      'cloudName': cloudName,
      'uploadPreset': uploadPreset,
      'uploadUrl': 'https://api.cloudinary.com/v1_1/$cloudName/image/upload'
    };
  }

  Future<void> deleteImage(String publicId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Chữ ký cho lệnh xóa yêu cầu public_id và timestamp
    final params = {
      'public_id': publicId,
      'timestamp': timestamp.toString(),
    };

    final sortedKeys = params.keys.toList()..sort();
    final paramString = sortedKeys.map((k) => '$k=${params[k]}').join('&');
    final stringToSign = '$paramString$apiSecret';
    final signature = sha1.convert(utf8.encode(stringToSign)).toString();

    final response = await http.post(
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy'),
      body: {
        'public_id': publicId,
        'timestamp': timestamp.toString(),
        'api_key': apiKey,
        'signature': signature,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete image from Cloudinary: ${response.body}');
    }

    final result = jsonDecode(response.body);
    if (result['result'] != 'ok') {
      throw Exception('Cloudinary delete error: ${result['result']}');
    }
  }
}
