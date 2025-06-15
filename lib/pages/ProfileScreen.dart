import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:task_management/pages/SplashScreen.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:task_management/utils/network_utils.dart';

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
  final TextEditingController _officeLocationController =
      TextEditingController();
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
    print("user: $user");
    final userEmail = user['userEmail'];
    if (userEmail == null) {
      setState(() {
        isLoading = false;
        errorMessage =
            'Something Went Wrong! Please try to Logout and login again';
      });
      return;
    }

    if (await NetworkUtils.hasInternetConnection()) {
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
            _officeLocationController.text =
                userData?["userAddressLine2"] ?? '';
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
          errorMessage = 'An error occurred While Fetching User Data';
        });
      }
    } else {
      setState(() {
        isLoading = false;
        errorMessage = 'No Internet Connection';
      });
    }
  }

  Future<void> changePasswordPopup() async {
    // Show Popup for writing message
    final passwordController = TextEditingController();

    final message = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create New Password'),
            content: TextField(
              controller: passwordController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pop(null), // Cancel and return null
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  // Pop and pass the text entered in the TextField
                  Navigator.of(context).pop(passwordController.text);
                },
                child: const Text('Send'),
              ),
            ],
          ),
    );

    // Use the returned message if needed
    if (message != null) {
      final accessToken = localStorage.getString('accessToken');
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/users/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'userPassword': passwordController.text,
          'userID': userData?["userID"],
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password updated successfully, Please wait while refreshing...',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => SplashScreen()),
          (Route route) => false,
        );
      } else {
        // show Bottom error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update message 🤔')),
        );
      }
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
      "userAddressLine2": _officeLocationController.text,
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
          localData["userAddressLine2"] = newData["userAddressLine2"];
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
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              )
              : errorMessage.isNotEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    SizedBox(height: 16),
                    Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Add retry logic here
                        setState(() => errorMessage = '');
                        fetchUserData();
                      },
                      style: ElevatedButton.styleFrom(
                        iconColor: Theme.of(context).primaryColor,
                      ),
                      child: Text('Try Again'),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Profile Picture Placeholder
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Form Fields
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _firstNameController,
                              decoration: InputDecoration(
                                labelText: 'First Name',
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _surnameController,
                              decoration: InputDecoration(
                                labelText: 'Surname',
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9]'),
                                ),
                              ],
                              maxLength: 10,
                              controller: _userPhoneController,
                              decoration: InputDecoration(
                                labelText: 'Contact Phone',
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _officeLocationController,
                              decoration: InputDecoration(
                                labelText: 'Office Location',
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                prefixIcon: Icon(Icons.work_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _addressLine1Controller,
                              decoration: InputDecoration(
                                labelText: 'Address',
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                prefixIcon: Icon(Icons.home_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _postcodeController,
                              decoration: InputDecoration(
                                labelText: 'Postcode',
                                labelStyle: TextStyle(color: Colors.grey[600]),
                                prefixIcon: Icon(Icons.location_on_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Action Buttons
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: updateUser,
                        style: ElevatedButton.styleFrom(
                          iconColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Text(
                            'UPDATE PROFILE',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    TextButton(
                      onPressed: changePasswordPopup,
                      child: Text(
                        'Change Password',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
