import 'dart:convert';
import 'package:http/http.dart' as http;
import 'get_service_key.dart';



class SendNotificationService {
  static Future<void> sendNotificationUsingApi({
    required String? token,
    required String? title,
    required String? body,
    required Map<String, dynamic>? data,
  }) async {
    try {
      String serverKey = await GetServerKey().getServerKeyToken();
      print("serverKey:---> $serverKey");
      String url =
          "https://fcm.googleapis.com/v1/projects/task-man-srinivas-2/messages:send";

      var headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $serverKey',
      };

      Map<String, dynamic> message = {
        "message": {
          "token": token,
          "notification": {"body": body, "title": title},
          "data": data,
        }
      };

      final http.Response response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(message),
      );

      if(response.statusCode == 200){
        print("Notification sent Successfully");
      }
      else{
        print("Notification send failed");
      }

      // final response = await http.post(
      //   Uri.parse(url),
      //   headers: headers,
      //   body: jsonEncode(message),
      // );
      //
      // if (response.statusCode != 200) {
      //   throw Exception('Failed to send notification');
      // }
    } catch (e) {
      throw Exception('Error sending notification: $e');
    }
  }
}