import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:task_management/resources/local_storage.dart';

typedef userRole = DropdownMenuEntry<UserTypeLabel>;

// DropdownMenuEntry labels and values for the first dropdown menu.
enum UserTypeLabel {
  normalUser('Normal User', 1),
  departmentAdmin('Department Admin', 2),
  superAdmin('Super Admin', 3);

  const UserTypeLabel(this.label, this.type);
  final String label;
  final int type;

  static final List<userRole> entries = UnmodifiableListView<userRole>(
    values.map<userRole>(
      (UserTypeLabel type) => userRole(
        value: type,
        label: type.label,
        // enabled: type.label != 'Grey',
        // style: MenuItemButton.styleFrom(foregroundColor: color.color),
      ),
    ),
  );
}

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> users = [];
  bool isLoading = true;
  String errorMessage = '';
  TextEditingController searchController = TextEditingController();
  var client = http.Client();
  static String baseURL = dotenv.get('HOST');
  Map<String, dynamic> currentUser = {};
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> userData = jsonDecode(
      jsonEncode(localStorage.getObject('userData') ?? {}),
    );
    currentUser = userData;

    // Now we can access currentUser safely
    isAdmin = currentUser['userRole'] != null && currentUser['userRole'] >= 2;

    fetchUsers();
  }

  Future<void> fetchUsers({String search = ''}) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final accessToken = await localStorage.getString('accessToken');
      print("AccessToken $accessToken");
      final response = await client.get(
        Uri.https(baseURL, '/api/v1/users/allUsers', {'search': search}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          users = jsonDecode(response.body)["data"];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load users';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'An error occurred: $e';
      });
    }
  }

  Future<void> addUser(Map<String, dynamic> userData) async {
    try {
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/users/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        fetchUsers(); // Refresh after adding user
      } else {
        var dataBody = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                dataBody["status"] == false && dataBody["msg"] != null
                    ? Text(dataBody["msg"])
                    : Text('Failed to add user'),
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

  Future<void> updateUser(Map<String, dynamic> userData) async {
    try {
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/users/update-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        fetchUsers(); // Refresh after updating user
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update user'),
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

  Future<void> deleteUser(String userId) async {
    try {
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/users/delete-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        fetchUsers(); // Refresh after deleting user
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user'),
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

  void showAddUserDialog() {
    final TextEditingController firstNameController = TextEditingController();
    final TextEditingController surnameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    // final TextEditingController passwordController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController userRoleController = TextEditingController();
    UserTypeLabel? userRole;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add User'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: firstNameController,
                    decoration: InputDecoration(labelText: 'First Name'),
                  ),
                  TextField(
                    controller: surnameController,
                    decoration: InputDecoration(labelText: 'Surname'),
                  ),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: 'Email'),
                  ),
                  // TextField(
                  //   controller: passwordController,
                  //   decoration: InputDecoration(labelText: 'Password'),
                  //   obscureText: true,
                  // ),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(labelText: 'Address'),
                  ),
                  DropdownMenu<UserTypeLabel>(
                    controller: userRoleController,
                    enableFilter: true,
                    requestFocusOnTap: true,
                    // leadingIcon: const Icon(Icons.search),
                    label: const Text('User Type'),
                    inputDecorationTheme: const InputDecorationTheme(
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 5.0),
                    ),
                    onSelected: (UserTypeLabel? role) {
                      setState(() {
                        userRole = role;
                      });
                    },
                    dropdownMenuEntries: UserTypeLabel.entries,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  addUser({
                    'userFirstName': firstNameController.text,
                    'userSurname': surnameController.text,
                    'userEmail': emailController.text,
                    // 'userPassword': passwordController.text,
                    'userAddressLine1': addressController.text,
                    'userRole': userRole?.type ?? 1,
                    "sendMail": true,
                  });
                  Navigator.of(context).pop();
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
  }

  void showEditUserDialog(Map<String, dynamic> user) {
    final TextEditingController firstNameController = TextEditingController(
      text: user["userFirstName"],
    );
    final TextEditingController surnameController = TextEditingController(
      text: user["userSurname"],
    );
    final TextEditingController userEmailController = TextEditingController(
      text: user["userEmail"],
    );
    final TextEditingController addressController = TextEditingController(
      text: user["userAddressLine1"],
    );
    UserTypeLabel? userRole = UserTypeLabel.values.firstWhere(
      (e) => e.type == user["userRole"],
      orElse: () => UserTypeLabel.normalUser, // fallback just in case
    );
    final TextEditingController userRoleController = TextEditingController(
      text: userRole.label,
    );
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit User'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: InputDecoration(labelText: 'First Name'),
                ),
                TextField(
                  controller: surnameController,
                  decoration: InputDecoration(labelText: 'Surname'),
                ),
                TextField(
                  controller: userEmailController,
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: 'Address'),
                ),

                isAdmin
                    ? DropdownMenu<UserTypeLabel>(
                      controller: userRoleController,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      // leadingIcon: const Icon(Icons.search),
                      label: const Text('User Type'),
                      inputDecorationTheme: const InputDecorationTheme(
                        filled: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 5.0),
                      ),
                      onSelected: (UserTypeLabel? role) {
                        setState(() {
                          userRole = role;
                        });
                      },
                      dropdownMenuEntries: UserTypeLabel.entries,
                    )
                    : Container(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  updateUser({
                    'userID': user["userID"],
                    'userFirstName': firstNameController.text,
                    'userSurname': surnameController.text,
                    'userAddressLine1': addressController.text,
                    'userRole': userRole?.type ?? user["userRole"],
                  });
                  Navigator.of(context).pop();
                },
                child: Text('Update'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Users')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                labelText: 'Search',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => fetchUsers(search: searchController.text),
                ),
              ),
            ),
          ),
          ElevatedButton(onPressed: showAddUserDialog, child: Text('Add User')),
          isLoading
              ? CircularProgressIndicator()
              : errorMessage.isNotEmpty
              ? Text(errorMessage, style: TextStyle(color: Colors.red))
              : Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Colors.blue, // You can customize the color
                        child: Icon(
                          Icons.person, // Profile icon
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        user["userFirstName"] + ' ' + user["userSurname"],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => showEditUserDialog(user),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}
