import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:task_management/pages/SettingsScreen.dart';
import 'package:task_management/resources/ThemeNotifier.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:task_management/utils/network_utils.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _progressValue = 0.0;
  String _statusMessage = 'Initializing...';
  bool _showOfflineButton = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    await localStorage.init();
    _isLoggedIn = localStorage.isLoggedIn();
    _navigateToNextScreen();
    _simulateProgress();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _simulateProgress() async {
    const totalSteps = 5;
    for (var i = 1; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        setState(() {
          _progressValue = i / totalSteps;
          _statusMessage = _getStatusMessage(i, totalSteps);
        });
      }
    }
  }

  String _getStatusMessage(int step, int total) {
    switch (step) {
      case 1:
        return 'Checking connection...';
      case 2:
        return 'Verifying credentials...';
      case 3:
        return 'Loading preferences...';
      case 4:
        return 'Preparing interface...';
      case 5:
        return 'Almost ready...';
      default:
        return 'Initializing...';
    }
  }

  final String baseURL = dotenv.get('HOST');

  Future<void> _navigateToNextScreen() async {
    try {
      // Check if user is logged in first
      if (_isLoggedIn) {
        // If logged in, proceed to home directly if offline
        if (!await NetworkUtils.hasInternetConnection()) {
          _updateStatus('Offline mode activated');
          await initSettings();
          _navigateToHome();
          return;
        }

        // If online, try silent login
        try {
          final userEmail = await localStorage.getString("loginUserEmail");
          final userPassword = await localStorage.getString(
            "loginUserPassword",
          );

          if (userEmail != null && userPassword != null) {
            _updateStatus('Authenticating...');
            final isLogin = await login(userEmail, userPassword);

            if (!isLogin) {
              // If login fails but user was previously logged in, show offline option
              _updateStatus('Connection issue - using offline data');
              await Future.delayed(const Duration(seconds: 2));
              _showOfflineOption();
              return;
            }
          }

          await initSettings();
          _navigateToHome();
        } catch (e) {
          debugPrint('Login error: $e');
          _showOfflineOption();
        }
      } else {
        // Not logged in - normal flow
        if (!await NetworkUtils.hasInternetConnection()) {
          _updateStatus('No internet connection');
          _navigateToLogin();
          return;
        }
        _navigateToLogin();
      }
    } catch (e) {
      debugPrint('Splash screen error: $e');
      if (_isLoggedIn) {
        _showOfflineOption();
      } else {
        _navigateToLogin();
      }
    }
  }

  void _showOfflineOption() {
    if (mounted) {
      setState(() {
        _statusMessage = 'Connection issues detected';
        _showOfflineButton = true;
      });
    }
  }

  Future<void> _navigateToHome() async {
    // wait for 2 sec
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }

  Future<void> _handleWakeLock() async {
    final wakeLockPref = await localStorage.getString('wakelock');
    final isWakeLock = wakeLockPref == 'true' ? true : false;

    debugPrint('🔒 isWakeLock: $isWakeLock');
    isWakeLock ? WakelockPlus.enable() : WakelockPlus.disable();
  }

  Future<void> _handleTheme() async {
    final themeModeStrPref = await localStorage.getString('themeMode');
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    switch (themeModeStrPref) {
      case 'light':
        themeNotifier.setThemeMode(AppThemeMode.light);
        break;
      case 'dark':
        themeNotifier.setThemeMode(AppThemeMode.dark);
        break;
      default:
        themeNotifier.setThemeMode(AppThemeMode.system);
    }
  }

  Future<void> initSettings() async {
    _handleTheme();
    _handleWakeLock();
  }

  Future<bool> login(String userEmail, String userPassword) async {
    final client = http.Client();
    try {
      _updateStatus('Connecting to server...');
      final response = await client
          .post(
            Uri.https(baseURL, '/api/v1/users/login'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'userEmail': userEmail,
              'userPassword': userPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint("Login status: ${response.statusCode}");

      if (response.statusCode >= 400) {
        // Don't fail immediately for 400+ status codes if already logged in
        return _isLoggedIn;
      }

      final responseData = json.decode(response.body);
      if (responseData['status'] != true) return _isLoggedIn;

      await _storeLoginData(responseData);
      return true;
    } on TimeoutException {
      _updateStatus('Connection timeout');
      return _isLoggedIn; // Return true if already logged in
    } catch (e) {
      debugPrint("Login error: $e");
      return _isLoggedIn; // Return true if already logged in
    } finally {
      client.close();
    }
  }

  Future<void> _storeLoginData(Map<String, dynamic> responseData) async {
    await Future.wait([
      localStorage.putString(
        'accessToken',
        responseData['data']['accessToken'],
      ),
      localStorage.putString(
        'refreshToken',
        responseData['data']['refreshToken'],
      ),
      localStorage.putObject('userData', responseData['data']['UserData']),
    ]);

    await localStorage.remove("fcmToken");
    await localStorage.setLoggedIn(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent.shade700,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _animation,
                child: Icon(Icons.task_alt, size: 100, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text(
                'TASK MANAGEMENT',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(2.0, 2.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: _progressValue,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              if (_showOfflineButton) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _navigateToHome,
                  child: const Text(
                    'Continue Offline',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
