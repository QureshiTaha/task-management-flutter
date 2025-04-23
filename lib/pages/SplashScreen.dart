// Improved Splash Screen
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:task_management/pages/HomeScreen.dart';
import 'package:task_management/resources/local_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
    _handleForegroundNotification();
  }

  Future<void> _handleForegroundNotification() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Extract notification data from the message
      final RemoteNotification? notification = message.notification;
      if (notification != null) {
        // Log notification details to the debug console
        debugPrint(
          '******** Received a message while in the foreground! ********',
        );
        debugPrint(
          '******** Notification Title: ${notification.title} ********',
        );
        debugPrint('******** Notification Body: ${notification.body} ********');
        debugPrint(
          '******** Notification Data: ${message.data.toString()} ********',
        );

        // Display a snack bar to inform the user about the notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            actionOverflowThreshold: 0.7,
            elevation: 2,
            showCloseIcon: true,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ).copyWith(side: const BorderSide(color: Colors.yellow)),
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAliasWithSaveLayer,

            content: Text(
              "🔔 ${notification.title} \n ${notification.body}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: ThemeData().colorScheme.secondary,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.green,
              onPressed: () {
                // Navigate to the TaskDetailScreen when the "View" button is pressed
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            ),
          ),
        );
      }
    });
  }

  void _navigateToNextScreen() async {
    await Future.delayed(Duration(seconds: 3));
    await localStorage.init();

    // Update Localstorage user, Fetch user and set it in localstorage
    final client = http.Client();

    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacementNamed(localStorage.isLoggedIn() ? '/home' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'TASK MANAGEMENT',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
