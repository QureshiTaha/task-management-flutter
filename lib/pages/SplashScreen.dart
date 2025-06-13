// Improved Splash Screen
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:task_management/pages/HomeScreen.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  }

  void _navigateToNextScreen() async {
    await Future.delayed(Duration(seconds: 3));
    await localStorage.init();

    bool isWakeLock =
        await localStorage.getString('wakeLock') != null &&
                localStorage.getString('wakeLock') == 'true'
            ? true
            : false;

    debugPrint('🔒 isWakeLock: $isWakeLock');

    if (isWakeLock)
      WakelockPlus.enable(); // Prevents the device from sleeping [Need IN Settings Page]

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
