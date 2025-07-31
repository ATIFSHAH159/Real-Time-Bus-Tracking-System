import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'Screens/splash_screen.dart';
import 'package:bus_tracking_system/Auth/login_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // You can add custom logic here, e.g., print or log the message
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Initialize Firebase with options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // ignore: avoid_print
    print('Firebase initialized successfully'); // Debugging log
  } catch (e) {
    // ignore: avoid_print
    print('Firebase initialization error: $e'); // Debugging log
  }
  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
       routes: {
    '/login': (context) => LoginPage(), // Ensure LoginScreen is imported
  },
      debugShowCheckedModeBanner: false,
      title: 'Bus Tracking System',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: SplashScreen(),
    );
  }
}
