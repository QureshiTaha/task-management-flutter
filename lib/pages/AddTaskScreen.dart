import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:http/http.dart' as http;
import 'package:task_management/resources/local_storage.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  String? selectedProjectID;
  String? selectedUserID;
  String taskTitle = '';
  String taskDescription = '';
  String taskStatus = 'not_assigned';
  static String baseURL = dotenv.get('HOST');
  String taskPriority = 'low';
  List<dynamic> projectList = [];
  List<dynamic> userList = [];
  var client = http.Client();
  final accessToken = localStorage.getString('accessToken');
  final Map<String, dynamic> user = jsonDecode(
    jsonEncode(localStorage.getObject('userData') ?? {}),
  );

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchProjects(String search) async {
    final response = await client.get(
      Uri.https(baseURL, '/api/v1/projects', {'search': search}),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 200) {
      setState(() {
        projectList = jsonDecode(response.body)["data"];
        debugPrint(projectList.toString());
      });
    }
  }

  Future<void> _fetchUsers(String search) async {
    final response = await client.get(
      Uri.https(baseURL, '/api/v1/users/allUsers', {'search': search}),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode == 200) {
      setState(() {
        userList = jsonDecode(response.body)["data"];
        print(userList);
      });
    }
  }

  Future<void> _submitTask() async {
    final userID = user['userID'];
    if (_formKey.currentState!.validate()) {
      final taskData = {
        "taskUserID": userID,
        "taskProjectID": selectedProjectID,
        "taskTitle": taskTitle,
        "taskDescription": taskDescription,
        "taskStatus": taskStatus,
        "taskPriority": taskPriority,
      };

      final response = await client.post(
        Uri.https(baseURL, '/api/v1/tasks'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(taskData),
      );

      if (response.statusCode == 200) {
        Navigator.of(context).pop();

        // Show success message in context
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully!')),
        );
      } else {
        print('Failed to create task: ${response.body}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Task Title
            TextFormField(
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (value) => taskTitle = value,
            ),
            // Task Description
            TextFormField(
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (value) => taskDescription = value,
            ),
            // Task Status Dropdown
            // DropdownButtonFormField<String>(
            //   value: taskStatus,
            //   items:
            //       ['not_assigned', 'pending', 'in_progress']
            //           .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            //           .toList(),
            //   onChanged: (value) => taskStatus = value!,
            //   decoration: const InputDecoration(labelText: 'Status'),
            // ),
            // Task Priority Dropdown
            DropdownButtonFormField<String>(
              value: taskPriority,
              items:
                  ['low', 'medium', 'high']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
              onChanged: (value) => taskPriority = value!,
              decoration: const InputDecoration(labelText: 'Priority'),
            ),
            // Searchable Project Dropdown
            TextFormField(
              decoration: const InputDecoration(labelText: 'Search Project'),
              onChanged: (value) => _fetchProjects(value),
            ),
            DropdownButtonFormField<String>(
              value: selectedProjectID,
              items:
                  projectList
                      .map(
                        (proj) => DropdownMenuItem<String>(
                          value: proj['projectID'],
                          child: Text(proj['name']), // Cast to String
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  selectedProjectID = value;
                });
              },
            ),

            // Searchable User Dropdown
            // TextFormField(
            //   decoration: const InputDecoration(labelText: 'Search User'),
            //   onChanged: (value) => _fetchUsers(value),
            // ),
            // DropdownButtonFormField<String>(
            //   value: selectedUserID,
            //   items:
            //       userList
            //           .map(
            //             (user) => DropdownMenuItem<String>(
            //               value: user['userID'] as String, // Cast to String
            //               child: Text(
            //                 user['userFirstName'] +
            //                     " " +
            //                     user['userSurname'] +
            //                     " ( " +
            //                     user['userEmail'] +
            //                     " )",
            //               ), // Cast to String
            //             ),
            //           )
            //           .toList(),
            //   onChanged: (value) {
            //     setState(() {
            //       selectedUserID = value!;
            //     });
            //   },
            // ),
            // Submit Button
            ElevatedButton(
              onPressed: _submitTask,
              child: const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }
}
