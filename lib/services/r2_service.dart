import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class R2Service {
  final String accessKey;
  final String secretKey;
  final String endpoint;
  final String bucketName;
  final String publicDomain;

  R2Service({
    required this.accessKey,
    required this.secretKey,
    required this.endpoint,
    required this.bucketName,
    required this.publicDomain,
  });

  String generatePresignedUrl(String objectKey, String method, {int expiresSeconds = 3600}) {
    final now = DateTime.now().toUtc();
    final amzDate = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(now);
    final datestamp = DateFormat("yyyyMMdd").format(now);

    final region = 'auto'; // R2 uses 'auto'
    final service = 's3';
    
    // 1. Canonical Request
    final httpMethod = method;
    final canonicalUri = '/$bucketName/$objectKey';
    
    final queryParams = {
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '$accessKey/$datestamp/$region/$service/aws4_request',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expiresSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    final sortedQueryString = queryParams.keys.toList()..sort();
    final canonicalQueryString = sortedQueryString.map((k) => '$k=${Uri.encodeComponent(queryParams[k]!)}').join('&');

    final host = endpoint.replaceFirst('https://', '');
    final canonicalHeaders = 'host:$host\n';
    final signedHeaders = 'host';
    final payloadHash = 'UNSIGNED-PAYLOAD';

    final canonicalRequest = '$httpMethod\n$canonicalUri\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$payloadHash';

    // 2. String to Sign
    final credentialScope = '$datestamp/$region/$service/aws4_request';
    final stringToSign = 'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest))}';

    // 3. Calculate Signature
    final signingKey = _getSignatureKey(secretKey, datestamp, region, service);
    final signature = hmacSha256(signingKey, stringToSign).toString();

    // 4. Final URL
    return '$endpoint$canonicalUri?$canonicalQueryString&X-Amz-Signature=$signature';
  }

  Future<void> deleteObject(String objectKey) async {
    try {
      final url = generatePresignedUrl(objectKey, 'DELETE');
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete object from R2: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  List<int> _getSignatureKey(String key, String dateStamp, String regionName, String serviceName) {
    final kDate = hmacSha256(utf8.encode('AWS4$key'), dateStamp);
    final kRegion = hmacSha256(kDate.bytes, regionName);
    final kService = hmacSha256(kRegion.bytes, serviceName);
    final kSigning = hmacSha256(kService.bytes, 'aws4_request');
    return kSigning.bytes;
  }

  Digest hmacSha256(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data));
  }

  String getPublicUrl(String objectKey) {
    return '$publicDomain/$objectKey';
  }
}
