// ignore_for_file: unused_local_variable

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
    // final IOSInitializationSettings initializationSettingsIOS =
    //     IOSInitializationSettings(
    //   requestAlertPermission: true,
    //   requestBadgePermission: true,
    //   requestSoundPermission: true,
    // );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          // iOS: initializationSettingsIOS,
        );
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // Create and configure the notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_notification_channel', // Channel ID
      'Default Channel', // Channel name
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notify'), // Specify the sound
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!
        .createNotificationChannel(channel);
  }

  Future<void> showForceNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          title,
          body,
          importance: Importance.max,
          priority: Priority.high,
          sound: const RawResourceAndroidNotificationSound('notify'),
          showWhen: false,
          playSound: true,
          ongoing: true, // this makes the notification non-removable
        );
    DarwinNotificationDetails iosPlatformChannelSpecifics =
        const DarwinNotificationDetails(
          sound: 'notification_sound.aiff',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: 'notify',
    );
  }

  Future<void> backgroundHandler(RemoteMessage message) async {
    // print("Handling background message: ${message.messageId}");

    // Show a high sound notification for background messages
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_sound_notification_channel', // Channel ID
          'High Sound Notification', // Channel name
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound(
            'notify',
          ), // Specify the high sound
          showWhen: false,
          playSound: true,
          ongoing: true, // this makes the notification non-removable
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // Show the high sound notification
    await flutterLocalNotificationsPlugin.show(
      1, // Notification ID
      message.notification!.title!,
      message.notification!.body!,
      platformChannelSpecifics,
      payload: 'high_sound_notification',
    );
  }

  Future<void> showPushNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          title,
          body,
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
          sound: const RawResourceAndroidNotificationSound('notify'),
          playSound: true,
          ongoing: false, // this makes the notification removable
        );
    DarwinNotificationDetails iosPlatformChannelSpecifics =
        const DarwinNotificationDetails(
          sound: 'notification_sound.aiff',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: 'notify',
    );
  }

  Future<void> cancelNotification(id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
