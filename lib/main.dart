import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:task_management/firebase_options.dart';
import 'package:task_management/pages/Messenger/ChatScreen.dart';
import 'package:task_management/resources/ThemeNotifier.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:task_management/resources/model/chatMessageModal.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:task_management/pages/HomeScreen.dart';
import 'package:task_management/pages/LoginScreen.dart';
import 'package:task_management/pages/Messenger/MessageHome.dart';
import 'package:task_management/pages/MyTaskScreen.dart';
import 'package:task_management/pages/ProfileScreen.dart';
import 'package:task_management/pages/ProjectsScreen.dart';
import 'package:task_management/pages/SplashScreen.dart';
import 'package:task_management/pages/SettingsScreen.dart';
import 'package:task_management/pages/WebDriveScreen.dart';
import 'package:task_management/pages/usersScreen.dart';
import 'package:task_management/resources/themeData.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main(context) async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await localStorage.init();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    initNotification(context);
    initLocalNotifications();
    _handleForegroundNotification(context);

    debugPrint("✅ Firebase Initialized Successfully");
  } catch (e) {
    debugPrint("❌ Firebase Initialization Error: $e");
  }

  // runApp(MyApp(context));
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: MyApp(context),
    ),
  );
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

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return Scaffold(
      body: Center(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          // theme: lightTheme,
          // darkTheme: darkTheme,
          theme: themeNotifier.currentTheme,

          themeMode: themeNotifier.themeMode,
          // localStorage.getString('themeMode') == 'dark'
          //     ? ThemeMode.dark
          //     : localStorage.getString('themeMode') == 'light'
          //     ? ThemeMode.light
          //     : ThemeMode
          //         .system, // Automatically switches based on system setting
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => SplashScreen(),
            '/login': (context) => LoginScreen(),
            '/home': (context) => HomeScreen(),
            '/profile': (context) => ProfileScreen(),
            '/settings': (context) => SettingsScreen(),
            '/users': (context) => UsersScreen(),
            '/projects': (context) => ProjectsScreen(),
            '/my-tasks':
                (context) =>
                    MyTaskScreen(projectID: '', tagName: '', projectName: ''),
            '/drive': (context) => WebDriveScreen(),
            '/message-home': (context) => MessengerHomeScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/chat') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                settings: RouteSettings(name: '/chat'),
                builder:
                    (context) => ChatScreen(
                      chatID: args['chatID'],
                      chatName: args['chatName'],
                      receiverUserID: args['receiverUserID'],
                      chatType: args['chatType'],
                    ),
              );
            }
            return null; // fallback for unknown routes
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

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
Future<void> initLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_stat_notify');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      handleNotificationClick(response);
    },
  );
  // await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> _handleForegroundNotification(context) async {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Extract notification data from the message
    final RemoteNotification? notification = message.notification;
    if (notification != null) {
      // Log notification details to the debug console
      debugPrint(
        '🔔****** Received a message while in the foreground! ******🔔',
      );
      debugPrint('******** Notification Title: ${notification.title} ********');
      debugPrint('******** Notification Body: ${notification.body} ********');
      debugPrint(
        '******** Notification Data: ${message.data.toString()} ********',
      );

      // show notification

      if (message.data.containsKey('chatID') &&
          message.data.containsKey('senderID')) {
        showLocalNotification(message.data);
      }
    }
  });
}

void showLocalNotification(message) {
  // Current route

  String? currentPath;

  navigatorKey.currentState?.popUntil((route) {
    currentPath = route.settings.name;
    return true;
  });
  print("👉currentRoute: $currentPath");
  print("👉message: $message");
  flutterLocalNotificationsPlugin.show(
    0,
    "New Message",
    message['message'] ?? "",
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_channel',
        'Chat Messages',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
    payload: jsonEncode(message),
  );
  // flutterLocalNotificationsPlugin.cancelAll();
}

// void handleNotificationClick(NotificationResponse response) {
//   if (response.payload != null) {
//     final payLoadJson = jsonDecode(response.payload!);
//     print('🔔🔔🔔Notification clicked with payload: ${payLoadJson}');
//     if (payLoadJson["chatID"] != null && payLoadJson["senderID"] != null) {
//       // If have message-home in route then pop to message-home else create routes start from home and go to message-home
//       if(){
//       navigatorKey.currentState!.popUntil(
//         (route) => route.settings.name == ('/message-home'),
//       );
//       }else{
//         //Some code here
// navigatorKey.currentState!.pushNamed('/message-home');
//       }
//     }
//     // Navigate to a specific screen or perform an action
//   }
// }

void handleNotificationClick(NotificationResponse response) {
  if (response.payload != null) {
    final payLoadJson = jsonDecode(response.payload!);
    print('🔔🔔🔔Notification clicked with payload: $payLoadJson');

    if (payLoadJson["chatID"] != null && payLoadJson["senderID"] != null) {
      bool messageHomeExists = false;

      navigatorKey.currentState!.popUntil((route) {
        if (route.settings.name == '/message-home') {
          messageHomeExists = true;
          return true;
        }
        return false;
      });

      if (!messageHomeExists) {
        navigatorKey.currentState!.pushNamed('/message-home');
      }

      // Optionally pass chatID and senderID to the message-home route
      // e.g., pushNamed('/message-home', arguments: {...});
    }
  }
}
