import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:api_cache_manager/models/cache_db_model.dart';
import 'package:api_cache_manager/utils/cache_manager.dart';
import 'package:task_management/resources/local_storage.dart';
import 'package:task_management/utils/network_utils.dart';

class AddTaskModal extends StatefulWidget {
  const AddTaskModal({Key? key}) : super(key: key);

  @override
  _AddTaskModalState createState() => _AddTaskModalState();
}

class _AddTaskModalState extends State<AddTaskModal> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> userData = {};
  String? selectedProjectID;
  String? taskTitle;
  String? taskDescription;
  String taskPriority = 'low';

  bool isSubmitting = false;
  bool showSuggestions =
      false; // Controls whether to show suggestions for projects
  bool showTagSuggestions = false; // For tags suggestions

  List<dynamic> projectList = [];
  List<dynamic> filteredProjects = [];
  List<dynamic> allTags = []; // All tags fetched from API
  List<dynamic> filteredTags = []; // Filtered tags based on search
  List<dynamic> selectedTags = []; // Tags selected by user

  final String baseURL = dotenv.get('HOST');
  final client = http.Client();

  Timer? debounceTimer;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tagSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    userData = jsonDecode(jsonEncode(localStorage.getObject('userData') ?? {}));
    _searchController.addListener(_onSearchChanged);
    _tagSearchController.addListener(_onTagSearchChanged);
    fetchTags(""); // fetch tags on init
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    client.close();
    _searchController.dispose();
    _tagSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final search = _searchController.text;
    if (search.isEmpty) {
      fetchProjects('');
    } else {
      fetchProjects(search);
    }
    setState(() {
      showSuggestions = true;
    });
  }

  void _onTagSearchChanged() {
    final search = _tagSearchController.text.toLowerCase();
    if (search.isEmpty) {
      setState(() {
        fetchTags('');
        // filteredTags = List.from(allTags);
      });
    } else {
      fetchTags(search);
      // setState(() {
      //   filteredTags =
      //       allTags
      //           .where((tag) => tag['name'].toLowerCase().contains(search))
      //           .toList();
      // });
    }
  }

  Future<void> fetchProjects(String search) async {
    String cacheKey = "project_list_search_$search";

    if ((!_searchController.text.isNotEmpty || showSuggestions) &&
        selectedProjectID == null) {
      setState(() {
        showSuggestions = true;
      });
    }

    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (search.isEmpty) {
        final cacheData = await APICacheManager().getCacheData(cacheKey);
        if (cacheData != null) {
          var cachedProjects = jsonDecode(cacheData.syncData)['data'];
          setState(() {
            projectList = cachedProjects;
            filteredProjects = cachedProjects;
          });
        }
        return;
      }

      if (await NetworkUtils.hasInternetConnection()) {
        final response = await client.get(
          Uri.https(baseURL, '/api/v1/projects', {'search': search}),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${localStorage.getString('accessToken')}',
          },
        );
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body)['data'];
          setState(() {
            projectList = data;
            filteredProjects = data;
          });
          await APICacheManager().addCacheData(
            APICacheDBModel(key: cacheKey, syncData: response.body),
          );
        }
      } else {
        final cacheData = await APICacheManager().getCacheData(cacheKey);
        if (cacheData != null) {
          var cachedProjects = jsonDecode(cacheData.syncData)['data'];
          setState(() {
            projectList = cachedProjects;
            filteredProjects = cachedProjects;
          });
        }
      }
    });
  }

  Future<void> fetchTags(String search) async {
    String cacheKey = "fetchTags_$search";
    final url = Uri.https(baseURL, '/api/v1/tasks/get-tags', {
      'search': search,
    });
    if (await NetworkUtils.hasInternetConnection()) {
      final response = await client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${localStorage.getString('accessToken')}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        // Save response to cache
        await APICacheManager().addCacheData(
          APICacheDBModel(key: cacheKey, syncData: response.body),
        );
        print(data);
        setState(() {
          allTags = data; // assuming data is list of tags with 'name' and 'id'
          filteredTags = List.from(allTags);
        });
      }
    } else {
      // handle offline if needed
      final cacheData = await APICacheManager().getCacheData(cacheKey);
      if (cacheData != null) {
        setState(() {
          allTags = jsonDecode(cacheData.syncData)['data'];
          filteredTags = List.from(allTags);
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);
    final userID = userData['userID'];
    final offlineID = 'offline_${DateTime.now().millisecondsSinceEpoch}';

    final tagIds = selectedTags
        .map((tag) => tag)
        .toList()
        .toString()
        .replaceAll('[', '')
        .replaceAll(']', '');

    print(tagIds);

    final taskData = {
      "offlineID": offlineID,
      "taskUserID": userID,
      "taskProjectID": selectedProjectID,
      "taskTitle": taskTitle,
      "taskDescription": taskDescription,
      "taskStatus": 'not_assigned',
      "taskPriority": taskPriority,
      "tag_name": tagIds, // send selected tags
    };
    print(taskData);
    if (await NetworkUtils.hasInternetConnection()) {
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/tasks'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(taskData),
      );
      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task created!')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to create task')));
      }
    } else {
      // Offline save logic
      String taskCacheKey = "task_list_$userID";
      print("offline task cache key: $taskCacheKey");
      final offlineTaskData = {
        "offlineID": offlineID,
        "created_by": userID,
        "taskProjectID": selectedProjectID,
        "title": taskTitle,
        "description": taskDescription,
        "status": "not_assigned",
        "priority": taskPriority,
        "created_at": DateTime.now().toString(),
        "updated_at": DateTime.now().toString(),
        "created_by_UserName":
            "${userData['userFirstName']}  ${userData['userSurname']}",
        "projectName": "offline",
      };
      // sync with locals..
      try {
        final cachedData = await APICacheManager().getCacheData(taskCacheKey);
        List<dynamic> existingTasks = [];

        if (cachedData != null) {
          final decoded = jsonDecode(cachedData.syncData);
          existingTasks = decoded['data'];
        }

        existingTasks.insert(0, offlineTaskData);

        await APICacheManager().addCacheData(
          APICacheDBModel(
            key: taskCacheKey,
            syncData: jsonEncode({"data": existingTasks}),
          ),
        );
        setState(() {
          isSubmitting = false;
        });
      } catch (e) {
        setState(() {
          isSubmitting = false;
        });
        print("Failed to update offline task cache: $e");
      }
      // Save task to local cache for syncing later
      List<Map<String, dynamic>> pendingTasks = [];
      try {
        var existing = await APICacheManager().getCacheData("offline_tasks");
        pendingTasks = List<Map<String, dynamic>>.from(
          jsonDecode(existing.syncData),
        );
      } catch (_) {}

      pendingTasks.add(taskData);

      await APICacheManager().addCacheData(
        APICacheDBModel(
          key: "offline_tasks",
          syncData: jsonEncode(pendingTasks),
        ),
      );

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task saved locally. Will sync when online.'),
        ),
      );
    }
    setState(() => isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final containerColor = isDarkMode ? Colors.grey[900] : Colors.white;
    final boxShadowColor = isDarkMode ? Colors.black54 : Colors.black26;
    final headerGradientColors =
        isDarkMode
            ? [Colors.teal.shade700, Colors.teal.shade400]
            : [Colors.blueAccent, Colors.lightBlue];

    final buttonBackgroundColor =
        isDarkMode ? Colors.tealAccent : Colors.blueAccent;
    final buttonTextColor = isDarkMode ? Colors.black : Colors.white;

    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Container(
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: boxShadowColor,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: headerGradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Text(
                  'Create New Task',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // Title
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Title',
                          filled: true,
                          fillColor:
                              isDarkMode ? Colors.grey[800] : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            Icons.title,
                            color: Colors.blueAccent,
                          ),
                        ),
                        validator:
                            (val) =>
                                val == null || val.isEmpty
                                    ? 'Enter title'
                                    : null,
                        onChanged: (val) => taskTitle = val,
                      ),
                      SizedBox(height: 12),
                      // Description
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Description',
                          filled: true,
                          fillColor:
                              isDarkMode ? Colors.grey[800] : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            Icons.description,
                            color: Colors.blueAccent,
                          ),
                        ),
                        maxLines: 3,
                        onChanged: (val) => taskDescription = val,
                      ),
                      SizedBox(height: 12),
                      // Priority Dropdown
                      DropdownButtonFormField<String>(
                        value: taskPriority,
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          filled: true,
                          fillColor:
                              isDarkMode ? Colors.grey[800] : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            Icons.flag,
                            color: Colors.blueAccent,
                          ),
                        ),
                        items:
                            ['low', 'medium', 'high']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) => taskPriority = val ?? 'low',
                      ),
                      SizedBox(height: 16),
                      // Project Search
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Select Project',
                          hintText: 'Search projects',
                          filled: true,
                          fillColor:
                              isDarkMode ? Colors.grey[800] : Colors.grey[100],
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.blueAccent,
                          ),
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      fetchProjects('');
                                      setState(() {
                                        showSuggestions = false;
                                      });
                                    },
                                  )
                                  : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            showSuggestions = true;
                          });
                        },
                      ),
                      if (showSuggestions && filteredProjects.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredProjects.length,
                            itemBuilder: (_, index) {
                              final proj = filteredProjects[index];
                              return ListTile(
                                title: Text(
                                  proj['name'],
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedProjectID = proj['projectID'];
                                    _searchController.text = proj['name'];
                                    showSuggestions = false;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      SizedBox(height: 20),
                      // Tags Search & Suggestion
                      TextField(
                        controller: _tagSearchController,
                        decoration: InputDecoration(
                          labelText: 'Select Tags',
                          hintText: 'Search tags',
                          filled: true,
                          fillColor:
                              isDarkMode ? Colors.grey[800] : Colors.grey[100],
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.blueAccent,
                          ),
                          suffixIcon:
                              _tagSearchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () {
                                      _tagSearchController.clear();
                                      setState(() {
                                        filteredTags = List.from(allTags);
                                      });
                                    },
                                  )
                                  : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            showTagSuggestions = true;
                          });
                        },
                      ),
                      if (showTagSuggestions && filteredTags.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredTags.length,
                            itemBuilder: (_, index) {
                              final tag = filteredTags[index];
                              final isSelected = selectedTags.any(
                                (t) => t == tag['tag_name'],
                              );
                              return ListTile(
                                title: Text(tag['tag_name']),
                                trailing:
                                    isSelected
                                        ? Icon(Icons.check, color: Colors.green)
                                        : null,
                                onTap: () {
                                  setState(() {
                                    if (!isSelected) {
                                      selectedTags.add(tag['tag_name']);
                                    } else {
                                      selectedTags.removeWhere(
                                        (t) => t['id'] == tag['id'],
                                      );
                                    }
                                    _tagSearchController.clear();
                                    filteredTags = List.from(allTags);
                                    showTagSuggestions = false;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      // Display selected tags as chips
                      if (selectedTags.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          children:
                              selectedTags.map((tag) {
                                return Chip(
                                  label: Text(tag),
                                  onDeleted: () {
                                    setState(() {
                                      print("selectedTags $selectedTags");
                                      selectedTags.removeWhere((t) => t == tag);
                                    });
                                  },
                                );
                              }).toList(),
                        ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: buttonBackgroundColor,
                          foregroundColor: buttonTextColor,
                          textStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: isSubmitting ? null : _submit,
                        child:
                            isSubmitting
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                : const Text('Create Task'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
