// // import 'dart:convert';
// // import 'package:http/http.dart' as http;
// // import 'get_service_key.dart';
// //
// //
// //
// // class SendNotificationService {
// //   static Future<void> sendNotificationUsingApi({
// //     required String? token,
// //     required String? title,
// //     required String? body,
// //     required Map<String, dynamic>? data,
// //   }) async {
// //     try {
// //       String serverKey = await GetServerKey().getServerKeyToken();
// //       print("serverKey:---> $serverKey");
// //       String url =
// //           "https://fcm.googleapis.com/v1/projects/task-man-srinivas-2/messages:send";
// //
// //       var headers = <String, String>{
// //         'Content-Type': 'application/json',
// //         'Authorization': 'Bearer $serverKey',
// //       };
// //
// //       Map<String, dynamic> message = {
// //         "message": {
// //           "token": token,
// //           "notification": {"body": body, "title": title},
// //           "data": data,
// //         }
// //       };
// //
// //       final http.Response response = await http.post(
// //         Uri.parse(url),
// //         headers: headers,
// //         body: jsonEncode(message),
// //       );
// //
// //       if(response.statusCode == 200){
// //         print("Notification sent Successfully");
// //       }
// //       else{
// //         print("Notification send failed");
// //       }
// //
// //       // final response = await http.post(
// //       //   Uri.parse(url),
// //       //   headers: headers,
// //       //   body: jsonEncode(message),
// //       // );
// //       //
// //       // if (response.statusCode != 200) {
// //       //   throw Exception('Failed to send notification');
// //       // }
// //     } catch (e) {
// //       throw Exception('Error sending notification: $e');
// //     }
// //   }
// // }
//
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter/foundation.dart';
//
// import 'get_service_key.dart'; // Adjust path to your GetServerKey implementation
//
// /// Result class for notification send operations
// class NotificationResult {
//   final bool success;
//   final String? message;
//   final Map<String, dynamic>? errorDetails;
//
//   NotificationResult({
//     required this.success,
//     this.message,
//     this.errorDetails,
//   });
// }
//
// /// A service for sending Firebase Cloud Messaging (FCM) push notifications
// /// using the HTTP v1 API. Supports single-device and topic-based notifications.
// class SendNotificationService {
//   // FCM HTTP v1 API endpoint
//   static const String _fcmUrl = 'https://fcm.googleapis.com/v1/projects/TaskManagement/messages:send';
//   static const int _timeoutSeconds = 30; // HTTP request timeout
//   static const int _maxRetries = 2; // Maximum retry attempts for transient errors
//
//   /// Sends a push notification to a single device or a topic.
//   /// - [token]: The FCM token of the target device (optional if topic is provided).
//   /// - [topic]: The FCM topic to send to (optional if token is provided).
//   /// - [title]: The notification title.
//   /// - [body]: The notification body.
//   /// - [data]: Custom data payload for the notification (optional).
//   /// Returns a [NotificationResult] indicating success or failure.
//   static Future<NotificationResult> sendNotification({
//     String? token,
//     String? topic,
//     required String title,
//     required String body,
//     Map<String, String>? data,
//   }) async {
//     // Validate inputs
//     if (token == null && topic == null) {
//       return NotificationResult(
//         success: false,
//         message: 'Either token or topic must be provided',
//       );
//     }
//     if (token != null && topic != null) {
//       return NotificationResult(
//         success: false,
//         message: 'Cannot specify both token and topic',
//       );
//     }
//     if (title.isEmpty) {
//       return NotificationResult(
//         success: false,
//         message: 'Notification title cannot be empty',
//       );
//     }
//     if (body.isEmpty) {
//       return NotificationResult(
//         success: false,
//         message: 'Notification body cannot be empty',
//       );
//     }
//
//     try {
//       // Retrieve server key
//       final String? serverKey = await GetServerKey().getServerKeyToken();
//       print("Server Key: --> $serverKey");
//       if (serverKey == null || serverKey.isEmpty) {
//         debugPrint('❌ Failed to retrieve FCM server key');
//         return NotificationResult(
//           success: false,
//           message: 'Failed to retrieve server key',
//         );
//       }
//       debugPrint('🔑 FCM Server Key retrieved successfully');
//
//       // Prepare headers
//       final headers = <String, String>{
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $serverKey',
//       };
//
//       // Prepare message payload
//       final Map<String, dynamic> message = {
//         'message': {
//           if (token != null) 'token': token,
//           if (topic != null) 'topic': topic,
//           'notification': {
//             'title': title,
//             'body': body,
//           },
//           'data': {
//             'type': data?['type'] ?? 'default',
//             'timestamp': DateTime.now().toIso8601String(),
//             // Ensure all data fields are strings
//             ...?data?.map((key, value) => MapEntry(key, value.toString())),
//           },
//           'android': {
//             'priority': 'high',
//             'notification': {
//               'channel_id': 'task_alarms', // Match the channel ID in AlarmService
//               'sound': 'alarm',
//               'priority': 'high',
//               'visibility': 'public',
//               'full_screen_intent': true,
//               'category': 'alarm',
//             },
//           },
//           'apns': {
//             'headers': {'apns-priority': '10'},
//             'payload': {
//               'aps': {
//                 'sound': 'default',
//                 'badge': 1,
//                 'category': 'ALARM',
//               },
//             },
//           },
//         },
//       };
//
//       // Send request with retry logic
//       int attempt = 0;
//       while (attempt <= _maxRetries) {
//         try {
//           final response = await http
//               .post(
//             Uri.parse(_fcmUrl),
//             headers: headers,
//             body: jsonEncode(message),
//           )
//               .timeout(Duration(seconds: _timeoutSeconds));
//
//           if (response.statusCode == 200) {
//             debugPrint('✅ Notification sent successfully: $title');
//             return NotificationResult(
//               success: true,
//               message: 'Notification sent successfully',
//             );
//           }
//
//           // Check if retryable
//           if (!_isRetryableStatusCode(response.statusCode)) {
//             final errorDetails = _parseFcmError(response);
//             debugPrint('❌ Notification send failed: ${response.statusCode} - ${response.body}');
//             return NotificationResult(
//               success: false,
//               message: 'Failed to send notification: ${response.statusCode}',
//               errorDetails: errorDetails,
//             );
//           }
//
//           attempt++;
//           debugPrint('⚠️ Retry attempt $attempt for status code: ${response.statusCode}');
//           await Future.delayed(Duration(milliseconds: 500 * attempt));
//         } catch (e) {
//           if (attempt == _maxRetries) {
//             debugPrint('❌ HTTP request failed after $_maxRetries retries: $e');
//             return NotificationResult(
//               success: false,
//               message: 'Error sending notification: $e',
//             );
//           }
//           attempt++;
//           debugPrint('⚠️ Retry attempt $attempt for error: $e');
//           await Future.delayed(Duration(milliseconds: 500 * attempt));
//         }
//       }
//
//       // Fallback for retry exhaustion
//       return NotificationResult(
//         success: false,
//         message: 'Failed to send notification after $_maxRetries retries',
//       );
//     } catch (e) {
//       debugPrint('❌ Error sending notification: $e');
//       return NotificationResult(
//         success: false,
//         message: 'Error sending notification: $e',
//       );
//     }
//   }
//
//   /// Checks if the status code is retryable (e.g., server or network issues).
//   static bool _isRetryableStatusCode(int statusCode) {
//     return statusCode >= 500 || statusCode == 429; // Server errors or rate limiting
//   }
//
//   /// Parses FCM error response for detailed error information.
//   static Map<String, dynamic>? _parseFcmError(http.Response response) {
//     try {
//       final body = jsonDecode(response.body);
//       return body['error'] as Map<String, dynamic>?;
//     } catch (e) {
//       debugPrint('⚠️ Failed to parse FCM error response: $e');
//       return {'statusCode': response.statusCode, 'body': response.body};
//     }
//   }
// }