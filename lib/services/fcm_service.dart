import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart';

class FcmService {
  final String _serviceAccountPath;
  AutoRefreshingAuthClient? _client;
  final _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  FcmService(this._serviceAccountPath);

  Future<AutoRefreshingAuthClient> _getClient() async {
    if (_client != null && _client!.credentials.accessToken.expiry.isAfter(DateTime.now().add(Duration(minutes: 5)))) {
      return _client!;
    }

    if (!File(_serviceAccountPath).existsSync()) {
      throw Exception('Firebase Service Account file not found at $_serviceAccountPath');
    }

    final jsonCredentials = await File(_serviceAccountPath).readAsString();
    final credentials = ServiceAccountCredentials.fromJson(jsonCredentials);
    _client = await clientViaServiceAccount(credentials, _scopes);
    return _client!;
  }

  Future<void> sendPushNotification({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (tokens.isEmpty) return;

    try {
      final client = await _getClient();
      final jsonCredentials = await File(_serviceAccountPath).readAsString();
      final decodedJson = jsonDecode(jsonCredentials);
      final projectId = decodedJson['project_id'];

      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      for (final token in tokens) {
        final payload = {
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            if (data != null) 'data': data.map((key, value) => MapEntry(key, value.toString())),
          }
        };

        final response = await client.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (response.statusCode != 200) {
          print('❌ FCM Error (${response.statusCode}): ${response.body}');
        } else {
          print('✅ FCM Success: Sent push to $token');
        }
      }
    } catch (e) {
      print('❌ FCM Exception: $e');
    }
  }
}
