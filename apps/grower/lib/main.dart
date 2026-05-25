import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'core/utils/notification_helper.dart';
import 'core/sync/sync_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize SyncEngine (Hive + Connectivity)
    await SyncEngine().init();

    // Request FCM permissions
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    await NotificationHelper.initialize();

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      NotificationHelper.showNotification(
        title: message.notification?.title ?? 'Micro-Harvest',
        body: message.notification?.body ?? '',
        payload: jsonEncode(message.data),
      );
    });

  } catch (e) {
    debugPrint('Firebase already initialized or failed: $e');
  }

  runApp(const MicroHarvestApp());
}
