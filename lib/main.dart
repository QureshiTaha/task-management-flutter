import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:task_management/firebase_options.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:task_management/pages/HomeScreen.dart';
import 'package:task_management/pages/LoginScreen.dart';
import 'package:task_management/pages/Messenger/MessageHome.dart';
import 'package:task_management/pages/MyTaskScreen.dart';
import 'package:task_management/pages/ProfileScreen.dart';
import 'package:task_management/pages/ProjectsScreen.dart';
import 'package:task_management/pages/SplashScreen.dart';
import 'package:task_management/pages/SettingsScreen.dart';
import 'package:task_management/pages/ProjectScreen.dart';
import 'package:task_management/pages/WebDriveScreen.dart';
import 'package:task_management/pages/usersScreen.dart';
import 'package:task_management/resources/themeData.dart';

void main(context) async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    initNotification(context);
    bool isWakeLock =
        await localStorage.getString('wakeLock') == 'true' ? true : false;

    if (isWakeLock)
      WakelockPlus.enable(); // Prevents the device from sleeping [Need IN Settings Page]

    debugPrint("Firebase Initialized Successfully");
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }

  runApp(MyApp(context));
}

class MyApp extends StatelessWidget {
  const MyApp(context, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MainApp());
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode:
              ThemeMode
                  .system, // Automatically switches based on system setting
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => SplashScreen(),
            '/login': (context) => LoginScreen(),
            '/home': (context) => HomeScreen(),
            '/profile': (context) => ProfileScreen(),
            '/settings': (context) => SettingsScreen(),
            '/users': (context) => UsersScreen(),
            '/projects': (context) => ProjectsScreen(),
            '/projectDetails': (context) => ProjectScreen(),
            '/my-tasks': (context) => MyTaskScreen(),
            '/drive': (context) => WebDriveScreen(),
            '/message-home': (context) => MessengerHomeScreen(),
          },
        ),
      ),
    );
  }
}

void initNotification(context) async {
  try {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    debugPrint('Token: $token');
  } catch (e) {
    debugPrint('Error: $e');
  }
}
