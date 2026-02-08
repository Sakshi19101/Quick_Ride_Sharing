import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:campus_ride_sharing_step1/service_account.dart';

class FCMService {
  static const String _projectId = 'campus-rideshare-2025';
  static const String _fcmUrl = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

  static Future<String> getAccessToken() async {
    final serviceAccountCredentials = auth.ServiceAccountCredentials.fromJson(ServiceAccount.json);
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = await auth.clientViaServiceAccount(serviceAccountCredentials, scopes);
    return client.credentials.accessToken.data;
  }

  static Future<Map<String, dynamic>> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('🔥 FCM Service (v1): Starting notification send...');
      print('🎯 Target Token: ${fcmToken.substring(0, 20)}...');
      print('📝 Title: $title');
      print('📄 Body: $body');
      print('📦 Data: $data');
      
      final accessToken = await getAccessToken();
      print('🔑 Access Token: ${accessToken.substring(0, 20)}...');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      final payload = {
        'message': {
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data ?? {},
        }
      };

      print('📤 Sending HTTP request to FCM v1 API...');
      print('🔗 URL: $_fcmUrl');
      print('📋 Headers: $headers');
      print('📦 Payload: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: headers,
        body: jsonEncode(payload),
      );

      print('📡 HTTP Response Status: ${response.statusCode}');
      print('📡 HTTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Notification sent successfully via FCM v1 API!');
        return {'success': true, 'response': jsonDecode(response.body)};
      } else {
        print('❌ FCM v1 API Error: ${response.statusCode} - ${response.body}');
        return {'success': false, 'error': 'HTTP ${response.statusCode}: ${response.body}'};
      }
    } catch (e) {
      print('❌ Exception in FCM v1 service: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
