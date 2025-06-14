// // AlarmController to manage state and lifecycle
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:get/get.dart';
// import 'package:get/get_core/src/get_main.dart';
//
// class AlarmController {
//   final FlutterLocalNotificationsPlugin notificationsPlugin =
//   FlutterLocalNotificationsPlugin();
//   final AudioPlayer audioPlayer = AudioPlayer();
//   bool _isAlarmPlaying = false;
//
//   bool get isAlarmPlaying => _isAlarmPlaying;
//
//   AlarmController() {
//     _initializeNotifications();
//     print('[Flutter] Initialized AlarmController at ${DateTime.now()}');
//   }
//
//   Future<void> _initializeNotifications() async {
//     print('[Flutter] Initializing notifications');
//
//     const androidChannel = AndroidNotificationChannel(
//       'alarm_channel',
//       'Alarm Notifications',
//       description: 'Notifications for alarm triggers',
//       importance: Importance.max,
//       playSound: false,
//       enableLights: true,
//       enableVibration: true,
//       showBadge: true,
//     );
//
//     final androidPlugin = notificationsPlugin
//         .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>();
//
//     try {
//       await androidPlugin?.createNotificationChannel(androidChannel);
//       print('[Flutter] Notification channel created: alarm_channel');
//     } catch (e) {
//       print('[Flutter] Error creating notification channel: $e');
//     }
//
//     const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
//     const initializationSettings = InitializationSettings(
//       android: androidSettings,
//     );
//
//     try {
//       await notificationsPlugin.initialize(
//         initializationSettings,
//         onDidReceiveNotificationResponse: (NotificationResponse response) async {
//           print('[Flutter] Notification response: actionId=${response.actionId}, '
//               'payload=${response.payload}, input=${response.input}');
//           if (response.actionId == 'snooze') {
//             print('[Flutter] Snooze action triggered');
//             await _stopAlarm();
//           } else {
//             print('[Flutter] Notification body tapped, stopping alarm');
//             await _stopAlarm();
//           }
//         },
//       );
//       print('[Flutter] Notifications initialized successfully');
//     } catch (e) {
//       print('[Flutter] Error initializing notifications: $e');
//     }
//
//     try {
//       final granted = await androidPlugin?.requestNotificationsPermission();
//       print('[Flutter] Notification permission granted: $granted');
//     } catch (e) {
//       print('[Flutter] Error requesting notification permission: $e');
//     }
//   }
//
//   // Future<void> triggerAlarm(BuildContext context) async {
//   //   if (_isAlarmPlaying) {
//   //     print('[Flutter] Alarm already playing');
//   //     return;
//   //   }
//   //
//   //   try {
//   //     print('[Flutter] Attempting to load and play alarm.mp3');
//   //     await audioPlayer.setReleaseMode(ReleaseMode.loop);
//   //     await audioPlayer.play(AssetSource('alarm.mp3'),
//   //         mode: PlayerMode.mediaPlayer);
//   //     print(
//   //         '[Flutter] Alarm.mp3 started playing, player state: ${audioPlayer.state}');
//   //     _isAlarmPlaying = true;
//   //
//   //     print('[Flutter] Showing notification');
//   //     const androidDetails = AndroidNotificationDetails(
//   //       'alarm_channel',
//   //       'Alarm Notifications',
//   //       channelDescription: 'Notifications for alarm triggers',
//   //       importance: Importance.max,
//   //       priority: Priority.high,
//   //       ongoing: false,
//   //       autoCancel: true,
//   //       enableLights: true,
//   //       enableVibration: true,
//   //       actions: <AndroidNotificationAction>[
//   //         AndroidNotificationAction(
//   //           'snooze',
//   //           'Snooze',
//   //           showsUserInterface: true,
//   //         ),
//   //       ],
//   //     );
//   //     const notificationDetails = NotificationDetails(android: androidDetails);
//   //
//   //     try {
//   //       await notificationsPlugin.show(
//   //         0,
//   //         'Alarm Triggered',
//   //         'Tap Snooze or notification to stop the alarm',
//   //         notificationDetails,
//   //       );
//   //       print('[Flutter] Notification shown successfully');
//   //     } catch (e) {
//   //       print('[Flutter] Error showing notification: $e');
//   //       if (context.mounted) {
//   //         ScaffoldMessenger.of(context).showSnackBar(
//   //           SnackBar(content: Text('Failed to show notification: $e')),
//   //         );
//   //       }
//   //     }
//   //   } catch (e) {
//   //     print('[Flutter] Error triggering alarm: $e');
//   //     if (context.mounted) {
//   //       ScaffoldMessenger.of(context).showSnackBar(
//   //         SnackBar(content: Text('Error triggering alarm: $e')),
//   //       );
//   //     }
//   //   }
//   // }
//
//   Future<void> triggerAlarm(BuildContext? context, {bool isFirebase = false}) async {
//     if (_isAlarmPlaying) {
//       debugPrint('[Flutter] Alarm already playing');
//       return;
//     }
//
//     try {
//       debugPrint('[Flutter] Attempting to load and play alarm.mp3');
//       await audioPlayer.setReleaseMode(ReleaseMode.loop);
//       await audioPlayer.play(AssetSource('alarm.mp3'), mode: PlayerMode.mediaPlayer);
//       debugPrint('[Flutter] Alarm.mp3 started playing, player state: ${audioPlayer.state}');
//       _isAlarmPlaying = true;
//
//       if (!isFirebase) {
//         debugPrint('[Flutter] Showing local notification');
//         const androidDetails = AndroidNotificationDetails(
//           'alarm_channel',
//           'Alarm Notifications',
//           channelDescription: 'Notifications for alarm triggers',
//           importance: Importance.max,
//           priority: Priority.high,
//           ongoing: false,
//           autoCancel: true,
//           enableLights: true,
//           enableVibration: true,
//           actions: [AndroidNotificationAction('snooze', 'Snooze')],
//         );
//         const notificationDetails = NotificationDetails(android: androidDetails);
//
//         try {
//           await notificationsPlugin.show(
//             0,
//             'Alarm Triggered',
//             'Tap Snooze to stop the alarm',
//             notificationDetails,
//             payload: 'stop_alarm',
//           );
//           debugPrint('[Flutter] Local notification shown successfully');
//         } catch (e) {
//           debugPrint('[Flutter] Error showing local notification: $e');
//           if (context != null && context.mounted) {
//             Get.snackbar('Error', 'Failed to show notification: $e');
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint('[Flutter] Error triggering alarm: $e');
//       if (context != null && context.mounted) {
//         Get.snackbar('Error', 'Error triggering alarm: $e');
//       }
//     }
//   }
//
//   Future<void> _stopAlarm() async {
//     print(
//         '[Flutter] Attempting to stop alarm, current state: ${audioPlayer.state}, isPlaying: $_isAlarmPlaying');
//     if (!_isAlarmPlaying) {
//       print('[Flutter] No alarm playing to stop');
//       return;
//     }
//
//     try {
//       await audioPlayer.stop();
//       print('[Flutter] Audio stopped, new state: ${audioPlayer.state}');
//       _isAlarmPlaying = false;
//       await notificationsPlugin.cancel(0);
//       print('[Flutter] Notification cancelled');
//     } catch (e) {
//       print('[Flutter] Error stopping alarm: $e');
//     }
//   }
//
//   Future<void> stopAlarm(BuildContext context) async {
//     await _stopAlarm();
//     if (context.mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Alarm snoozed')),
//       );
//     }
//   }
//
//   Future<void> checkNotificationSettings() async {
//     final androidPlugin = notificationsPlugin
//         .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>();
//     final granted = await androidPlugin?.requestNotificationsPermission();
//     print('[Flutter] Notification permission granted: $granted');
//   }
//
//   void dispose() {
//     print('[Flutter] Disposing AlarmController');
//     audioPlayer.dispose();
//   }
// }
//
// // Modified AlarmApp to manage AlarmController
// // class AlarmApp extends StatefulWidget {
// //   const AlarmApp({Key? key}) : super(key: key);
// //
// //   @override
// //   _AlarmAppState createState() => _AlarmAppState();
// // }
// //
// // class _AlarmAppState extends State<AlarmApp> {
// //   final AlarmController controller = AlarmController();
// //
// //   @override
// //   void dispose() {
// //     controller.dispose();
// //     super.dispose();
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return MaterialApp(
// //       home: AlarmHomePage(controller: controller),
// //     );
// //   }
// // }
// //
// // // Corrected StatelessWidget
// // class AlarmHomePage extends StatelessWidget {
// //   final AlarmController controller;
// //
// //   const AlarmHomePage({Key? key, required this.controller}) : super(key: key);
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text('Simple Alarm')),
// //       body: Center(
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             ElevatedButton(
// //               onPressed: () => controller.triggerAlarm(context),
// //               child: const Text('Trigger Alarm'),
// //             ),
// //             const SizedBox(height: 20),
// //             ValueListenableBuilder<bool>(
// //               valueListenable: ValueNotifier<bool>(controller.isAlarmPlaying),
// //               builder: (context, isPlaying, child) {
// //                 return ElevatedButton(
// //                   onPressed: isPlaying ? () => controller.stopAlarm(context) : null,
// //                   child: const Text('Stop Alarm'),
// //                 );
// //               },
// //             ),
// //             const SizedBox(height: 20),
// //             ElevatedButton(
// //               onPressed: controller.checkNotificationSettings,
// //               child: const Text('Check Notification Settings'),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }