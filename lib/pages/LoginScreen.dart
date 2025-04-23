import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:task_management/resources/local_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  static String baseURL = dotenv.get('HOST');

  bool _isLoading = false;

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    if (_userEmailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Please fill in both username and password');
      return;
    }

    var client = http.Client();
    try {
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/users/login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'userEmail': _userEmailController.text,
          'userPassword': _passwordController.text,
        }),
      );

      setState(() => _isLoading = false);
      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
        localStorage.putString(
          'accessToken',
          responseData['data']['accessToken'],
        );
        localStorage.putString(
          'refreshToken',
          responseData['data']['refreshToken'],
        );
        localStorage.putObject('userData', responseData['data']['UserData']);
        localStorage.remove("fcmToken");
        localStorage.setLoggedIn(true);
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _showErrorSnackbar(
          responseData['msg'] ?? 'Login failed. Please try again.',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('An error occurred. Please try again.');
      debugPrint(e.toString());
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              SizedBox(height: 10),
              Text(
                'Login to continue',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              SizedBox(height: 30),
              TextField(
                controller: _userEmailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child:
                      _isLoading
                          ? CircularProgressIndicator()
                          : Text('Login', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
