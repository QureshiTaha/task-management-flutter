// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:task_management/resources/local_storage.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  _ProjectsScreenState createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<dynamic> projects = [];
  bool isLoading = true;
  String errorMessage = '';
  TextEditingController searchController = TextEditingController();
  var client = http.Client();
  var accessToken = localStorage.getString('accessToken');
  static String baseURL = dotenv.get('HOST');

  @override
  void initState() {
    super.initState();
    fetchProjects();
  }

  Future<void> fetchProjects({
    String search = '',
    int page = 1,
    int limit = 10,
  }) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final response = await client.get(
        Uri.https(baseURL, '/api/v1/projects', {
          'search': search,
          'page': '$page',
          'limit': '$limit',
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken', // Add your token here
        },
      );

      var dataBody = jsonDecode(response.body);
      print(dataBody);

      if (response.statusCode == 200) {
        setState(() {
          projects = jsonDecode(response.body)["data"];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage =
              dataBody["success"] == false && dataBody["message"] != null
                  ? dataBody["message"]
                  : 'Failed to load projects';
        });
      }
    } catch (e) {
      print("ERROR:" + e.toString());
      setState(() {
        isLoading = false;
        errorMessage = 'An error occurred: $e';
      });
    }
  }

  Future<void> addProject(Map<String, dynamic> projectData) async {
    try {
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/projects'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken', // Add your token here
        },
        body: jsonEncode(projectData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        fetchProjects(); // Refresh after adding project
      } else {
        var dataBody = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                dataBody["status"] == false && dataBody["msg"] != null
                    ? Text(dataBody["msg"])
                    : Text('Failed to add project'),
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

  Future<void> updateProject(
    Map<String, dynamic> projectData,
    String projectId,
  ) async {
    try {
      final response = await client.put(
        Uri.https(baseURL, '/api/v1/projects/edit/$projectId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken', // Add your token here
        },
        body: jsonEncode(projectData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        fetchProjects(); // Refresh after updating project
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update project'),
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

  Future<void> deleteProject(String projectId) async {
    bool? confirmDelete = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Project'),
            content: const Text(
              'Are you sure you want to delete this project?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // Cancel
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(
                    context,
                  ).pop(true); // Close dialog before proceeding
                },
                child: const Text('Yes'),
              ),
            ],
          ),
    );

    if (confirmDelete == true) {
      try {
        final response = await client.delete(
          Uri.https(baseURL, '/api/v1/projects/$projectId'),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Project deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          fetchProjects(); // Refresh after deleting project
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete project'),
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
  }

  void showAddProjectDialog() {
    final TextEditingController projectNameController = TextEditingController();
    final TextEditingController projectDescriptionController =
        TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Project'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: projectNameController,
                  decoration: InputDecoration(labelText: 'Project Name'),
                ),
                TextField(
                  controller: projectDescriptionController,
                  decoration: InputDecoration(labelText: 'Project Description'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  addProject({
                    'projectName': projectNameController.text,
                    'projectDescription': projectDescriptionController.text,
                  });
                  Navigator.of(context).pop();
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
  }

  void showEditProjectDialog(Map<String, dynamic> project) {
    final TextEditingController projectNameController = TextEditingController(
      text: project["projectName"],
    );
    final TextEditingController projectDescriptionController =
        TextEditingController(text: project["projectDescription"]);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Project'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: projectNameController,
                  decoration: InputDecoration(labelText: 'Project Name'),
                ),
                TextField(
                  controller: projectDescriptionController,
                  decoration: InputDecoration(labelText: 'Project Description'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  updateProject({
                    'projectName': projectNameController.text,
                    'projectDescription': projectDescriptionController.text,
                  }, project["projectID"]);
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
      appBar: AppBar(title: const Text('Projects')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => fetchProjects(search: searchController.text),
                ),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: showAddProjectDialog,
            child: Text('Add Project'),
          ),
          isLoading
              ? CircularProgressIndicator()
              : errorMessage.isNotEmpty
              ? Text(errorMessage, style: TextStyle(color: Colors.red))
              : Expanded(
                child: ListView.builder(
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final projectID = project["projectID"];
                    return ListTile(
                      enableFeedback: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      // tileColor: Colors.black45,
                      minVerticalPadding: 0.0,
                      title: Text(project["name"]),
                      subtitle: Text(project["description"]),
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      // on tap navigate with projectID
                      // onTap: () => showEditProjectDialog(project),
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/projectDetails',
                            arguments: {"projectID": projectID, ...project},
                          ),
                      onLongPress: () => showEditProjectDialog(project),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_forever),
                        color: Colors.red,
                        onPressed:
                            () => deleteProject(
                              projectID,
                            ).then((value) => fetchProjects()),
                        // : () => Navigator.pushNamed(context, '/users'),
                      ),
                      shape: Border(bottom: BorderSide(color: Colors.grey)),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}
