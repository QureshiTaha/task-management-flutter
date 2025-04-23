import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:task_management/pages/SplashScreen.dart';
import 'package:task_management/resources/local_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? rawUserData;
  bool isLoading = true;
  String errorMessage = '';
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _userPhoneController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  var client = http.Client();
  static String baseURL = dotenv.get('HOST');

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final Map<String, dynamic> user = jsonDecode(
      jsonEncode(localStorage.getObject('userData') ?? {}),
    );
    final userEmail = user['userEmail'];
    if (userEmail == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'User email not found';
      });
      return;
    }

    try {
      final response = await client.get(
        Uri.https("$baseURL", '/api/v1/users/getUserByEmail/$userEmail'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
      );
      if (response.statusCode == 200) {
        setState(() {
          rawUserData = jsonDecode(response.body);
          userData = rawUserData?["data"][0];
          isLoading = false;
          _firstNameController.text = userData?["userFirstName"] ?? '';
          _surnameController.text = userData?["userSurname"] ?? '';
          _addressLine1Controller.text = userData?["userAddressLine1"] ?? '';
          _postcodeController.text = userData?["userAddressPostcode"] ?? '';
          _userPhoneController.text = userData?["userPhone"].toString() ?? '';
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load user data';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'An error occurred: $e';
      });
    }
  }

  Future<void> updateUser() async {
    if (_firstNameController.text.isEmpty ||
        _surnameController.text.isEmpty ||
        _userPhoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (userData == null) return;
    final Map<String, dynamic> updatedData = {
      "userID": userData?["userID"],
      "userFirstName": _firstNameController.text,
      "userSurname": _surnameController.text,
      "userAddressLine1": _addressLine1Controller.text,
      "userAddressLine2": userData?["userAddressLine2"],
      "userAddressPostcode": _postcodeController.text,
      "userPhone": _userPhoneController.text,
      "userGender": userData?["userGender"],
    };

    try {
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/users/update-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updatedData),
      );

      if (response.statusCode == 200) {
        var newData = jsonDecode(response.body)["data"];
        var localData = localStorage.getObject('userData');

        if (localData is Map<String, dynamic>) {
          localData["userFirstName"] = newData["userFirstName"];
          localData["userSurname"] = newData["userSurname"];
          localData["userAddressLine1"] = newData["userAddressLine1"];
          localData["userAddressPostcode"] = newData["userAddressPostcode"];
          localData["userPhone"] = newData["userPhone"];

          // You can add any other fields from `newData` here if you need

          localStorage.putObject('userData', localData);
        } else {
          Map<String, dynamic> newLocalData = {
            ...newData,
            "userFirstName": newData["userFirstName"],
            "userSurname": newData["userSurname"],
            "userAddressLine1": newData["userAddressLine1"],
            "userAddressLine2": newData["userAddressLine2"],
            "userAddressPostcode": newData["userAddressPostcode"],
          };

          localStorage.putObject('userData', newLocalData);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully, Please wait while refreshing...',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => SplashScreen()),
          (Route route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
              ? Center(
                child: Text(errorMessage, style: TextStyle(color: Colors.red)),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _firstNameController,
                      decoration: InputDecoration(labelText: 'First Name*'),
                    ),
                    TextField(
                      controller: _surnameController,
                      decoration: InputDecoration(labelText: 'Surname*'),
                    ),
                    TextField(
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                      ],
                      maxLength: 10,
                      controller: _userPhoneController,
                      decoration: InputDecoration(labelText: 'Contact Phone*'),
                    ),
                    TextField(
                      controller: _addressLine1Controller,
                      decoration: InputDecoration(labelText: 'Address'),
                    ),
                    TextField(
                      controller: _postcodeController,
                      decoration: InputDecoration(labelText: 'Postcode'),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: updateUser,
                      child: Text('Update Profile'),
                    ),
                  ],
                ),
              ),
    );
  }
}
