import 'dart:convert';

import 'package:bus_tracking_system/Services/get_server_key.dart';
import 'package:http/http.dart' as http;

class SendNotificationService {
  static Future<void> sendNotificationUsingApi({
    required String? token,
    required String? title,
    required String? body,
    required Map<String, dynamic>? data,
  }) async {
    String serverkey = await GetServerKey().getServerKeyToken();
    print('FCM Server Key: $serverkey');
    String url = "https://fcm.googleapis.com/v1/projects/rtbts-74160/messages:send";

    var headers = <String, String>{
      "Content-Type": "application/json",
      "Authorization": "Bearer $serverkey",
    };
    //message
    Map<String, dynamic> message = {
      "message": {
        "token": token,
        "notification": {
          "body": body,
          "title": title,
        },
        "data": data
      }
    };
    
    print('Sending notification with payload: ${jsonEncode(message)}');
    print('Using headers: $headers');
    
    //hit api
    try {
      final http.Response response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(message),
      );
      
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        print("notification sent successfully");
      } else {
        final responseData = json.decode(response.body);
        if (responseData['error'] != null) {
          final error = responseData['error'];
          if (error['details'] != null && 
              error['details'][0]['errorCode'] == 'UNREGISTERED') {
            throw Exception('UNREGISTERED');
          }
        }
        print("notification not sent. Error: ${response.body}");
        throw Exception('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      print('Exception while sending notification: $e');
      rethrow; // Rethrow to handle in the calling function
    }
  }

  Future<void> notifyUser({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required String token,
  }) async {
    print('Attempting to notify user with token: $token');
    await SendNotificationService.sendNotificationUsingApi(
      token: token,
      title: title,
      body: body,
      data: data,
    );
  }
}
