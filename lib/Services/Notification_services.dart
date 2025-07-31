import 'dart:io';

import 'package:bus_tracking_system/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:bus_tracking_system/Services/send_notification_service.dart';

const String defaultChannelId = 'ecomm-channel';

class NotificationServices {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  void requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      Get.snackbar(
        'Notification Permission denied',
        'Please grant notification permission to receive updates',
        snackPosition: SnackPosition.BOTTOM,
      );
      Future.delayed(const Duration(seconds: 3), () {
        AppSettings.openAppSettings(type: AppSettingsType.notification);
      });
    }
  }

  Future<String> getDeviceToken() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    String? token = await messaging.getToken();
    print('Device Token: $token');
    return token!;
  }

  void initLocalNotification(BuildContext context, RemoteMessage message) async {
    var androidInitSetting = const AndroidInitializationSettings('@mipmap/ic_launcher');
    var iosInitSetting = const DarwinInitializationSettings();
    var initializationSetting = InitializationSettings(
      android: androidInitSetting,
      iOS: iosInitSetting,
    );
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSetting,
      onDidReceiveNotificationResponse: (payload) {
        handleMessage(context, message);
      },
    );
  }

  void firebaseInit(BuildContext context) {
    FirebaseMessaging.onMessage.listen((message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification!.android;
      if (kDebugMode) {
        print('notification title: [32m${notification!.title}[0m');
        print('notification body: [32m${notification.body}[0m');
      }
      // iOS
      if (Platform.isIOS) {
        iosForegroundMessage();
      }
      // Android
      if (Platform.isAndroid) {
        initLocalNotification(context, message);
        showNotification(message);
      }
    });
  }

  Future<void> showNotification(RemoteMessage message) async {
    // Channel setting
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      defaultChannelId,
      'General Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      showBadge: true,
      playSound: true,
    );
    // Android setting
    AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      defaultChannelId,
      'General Notifications',
      channelDescription: "This channel is used for important notifications.",
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: channel.sound,
    );

    // iOS Setting
    DarwinNotificationDetails darwinNotificationDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    // Show notification
    Future.delayed(Duration.zero, () {
      _flutterLocalNotificationsPlugin.show(
        0,
        message.notification!.title.toString(),
        message.notification!.body.toString(),
        notificationDetails,
        payload: "my-data",
      );
    });
  }

  Future<void> setupInteractMessage(BuildContext context) async {
    // Background state
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handleMessage(context, message);
    });

    // Terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && message.data.isNotEmpty) {
        handleMessage(context, message);
      }
    });
  }

  Future<void> handleMessage(BuildContext context, RemoteMessage message) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyApp()),
    );
  }

  Future iosForegroundMessage() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> saveDeviceTokenToDatabase(String token, String userId, String userType) async {
    await FirebaseFirestore.instance
        .collection(userType) // 'users' or 'drivers'
        .doc(userId)
        .update({'fcmToken': token});
  }

  Future<List<String>> fetchAllUserTokens() async {
    List<String> tokens = [];
    print('Fetching all user tokens...');

    // Fetch from users
    var users = await FirebaseFirestore.instance.collection('users').get();
    print('Found ${users.docs.length} users');
    for (var doc in users.docs) {
      if (doc.data().containsKey('fcmToken') && doc['fcmToken'] != null) {
        print('Found token for user ${doc.id}: ${doc['fcmToken']}');
        tokens.add(doc['fcmToken']);
      }
    }

    // Fetch from drivers
    var drivers = await FirebaseFirestore.instance.collection('drivers').get();
    print('Found ${drivers.docs.length} drivers');
    for (var doc in drivers.docs) {
      if (doc.data().containsKey('fcmToken') && doc['fcmToken'] != null) {
        print('Found token for driver ${doc.id}: ${doc['fcmToken']}');
        tokens.add(doc['fcmToken']);
      }
    }

    print('Total tokens found: ${tokens.length}');
    return tokens;
  }

  Future<void> saveNotificationToDatabase({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required List<String> recipients,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'body': body,
      'data': data,
      'recipients': recipients,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> notifyAllUsers(String title, String body, Map<String, dynamic> data) async {
    print('Starting notifyAllUsers with title: $title');
    List<String> tokens = await fetchAllUserTokens();
    print('Sending notifications to ${tokens.length} users');
    
    List<String> invalidTokens = [];
    
    for (String token in tokens) {
      print('Sending notification to token: $token');
      try {
      await SendNotificationService().notifyUser(
        title: title,
        body: body,
        data: data,
        token: token,
      );
      } catch (e) {
        if (e.toString().contains('UNREGISTERED')) {
          print('Found invalid token: $token');
          invalidTokens.add(token);
        }
      }
    }
    
    // Clean up invalid tokens
    if (invalidTokens.isNotEmpty) {
      print('Cleaning up ${invalidTokens.length} invalid tokens');
      await _cleanupInvalidTokens(invalidTokens);
    }
    
    // Store notification in Firestore
    print('Storing notification in Firestore');
    await saveNotificationToDatabase(
      title: title,
      body: body,
      data: data,
      recipients: tokens,
    );
    print('Notification process completed');
  }

  Future<void> _cleanupInvalidTokens(List<String> invalidTokens) async {
    // Clean up from users collection
    var users = await FirebaseFirestore.instance.collection('users').get();
    for (var doc in users.docs) {
      if (doc.data().containsKey('fcmToken') && 
          invalidTokens.contains(doc['fcmToken'])) {
        await doc.reference.update({'fcmToken': FieldValue.delete()});
        print('Removed invalid token from user ${doc.id}');
      }
    }

    // Clean up from drivers collection
    var drivers = await FirebaseFirestore.instance.collection('drivers').get();
    for (var doc in drivers.docs) {
      if (doc.data().containsKey('fcmToken') && 
          invalidTokens.contains(doc['fcmToken'])) {
        await doc.reference.update({'fcmToken': FieldValue.delete()});
        print('Removed invalid token from driver ${doc.id}');
      }
    }
  }

  Future<void> notifyUser({ required String title,required String body,required Map<String, dynamic> data,required String token,}) async {
    await SendNotificationService().notifyUser(
      title: title,
      body: body,
      data: data,
      token: token,
    );
  }
}