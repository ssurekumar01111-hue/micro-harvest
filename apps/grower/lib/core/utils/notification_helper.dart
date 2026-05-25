import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings settings = InitializationSettings(android: android);
    
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'micro_harvest_channel',
      'Micro-Harvest Alerts',
      description: 'Listing and handoff alerts',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap
    final payload = response.payload;
    if (payload != null) {
      try {
        final data = jsonDecode(payload);
        debugPrint('Notification payload: $data');
      } catch (e) {
        debugPrint('Error decoding notification payload: $e');
      }
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'micro_harvest_channel',
      'Micro-Harvest Alerts',
      channelDescription: 'Listing alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: android);

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
