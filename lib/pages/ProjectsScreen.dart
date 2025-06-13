import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:task_management/resources/local_storage.dart';
import 'package:task_management/utils/AnimatedFabFloating.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  _ProjectsScreenState createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> projects = [];
  List<dynamic> tags = [];
  bool isLoading = true;
  String errorMessage = '';
  Timer? _debounce;
  TextEditingController searchController = TextEditingController();
  var client = http.Client();
  var accessToken = localStorage.getString('accessToken');
  static String baseURL = dotenv.get('HOST');
  ScrollController _projectsScrollController = ScrollController();
  ScrollController _tagsScrollController = ScrollController();
  int currentProjectsPage = 1;
  int currentTagsPage = 1;
  bool haveMoreProjects = true;
  bool haveMoreTags = true;
  bool isFetchingMoreProjects = false;
  bool isFetchingMoreTags = false;
  bool showAddText = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchProjects();
    fetchTags();

    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          showAddText = true;
        });
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              showAddText = false;
            });
          }
        });
      }
    });

    searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();

      _debounce = Timer(const Duration(milliseconds: 500), () {
        final query = searchController.text.trim();
        if (query.isEmpty) {
          if (_tabController.index == 0) {
            currentProjectsPage = 1;
            haveMoreProjects = true;
            isFetchingMoreProjects = false;
            fetchProjects();
          } else {
            currentTagsPage = 1;
            haveMoreTags = true;
            isFetchingMoreTags = false;
            fetchTags();
          }
        } else {
          if (_tabController.index == 0) {
            fetchProjects(search: query);
          } else {
            fetchTags(search: query);
          }
        }
      });
    });

    _projectsScrollController.addListener(() {
      if (_projectsScrollController.position.pixels >=
          _projectsScrollController.position.maxScrollExtent - 200) {
        if (haveMoreProjects && !isFetchingMoreProjects) {
          currentProjectsPage++;
          fetchProjects(page: currentProjectsPage);
        }
      }
    });

    _tagsScrollController.addListener(() {
      if (_tagsScrollController.position.pixels >=
          _tagsScrollController.position.maxScrollExtent - 200) {
        if (haveMoreTags && !isFetchingMoreTags) {
          currentTagsPage++;
          fetchTags(page: currentTagsPage);
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    _projectsScrollController.dispose();
    _tagsScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchProjects({
    String search = '',
    int page = 1,
    int limit = 10,
  }) async {
    setState(() {
      if (page == 1) isLoading = true;
      isFetchingMoreProjects = true;
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
          'Authorization': 'Bearer $accessToken',
        },
      );

      final dataBody = jsonDecode(response.body);

      if (response.statusCode == 200 && dataBody["success"] == true) {
        final List newProjects = dataBody["data"];
        final bool serverHasMore =
            dataBody["data"].isNotEmpty &&
            (dataBody["data"].last["haveMore"] ?? false);

        setState(() {
          if (page == 1) {
            projects = newProjects;
          } else {
            projects.addAll(newProjects);
          }
          isLoading = false;
          haveMoreProjects = serverHasMore;
          isFetchingMoreProjects = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isFetchingMoreProjects = false;
          errorMessage = dataBody["message"] ?? 'Failed to load projects';
        });
      }
    } catch (e) {
      debugPrint("ERROR:" + e.toString());
      setState(() {
        isLoading = false;
        isFetchingMoreProjects = false;
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
          'Authorization': 'Bearer $accessToken',
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
        fetchProjects();
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
          'Authorization': 'Bearer $accessToken',
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
        fetchProjects();
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
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
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
          fetchProjects();
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

  Future<void> fetchTags({
    String search = '',
    int page = 1,
    int limit = 50,
  }) async {
    setState(() {
      if (page == 1) isLoading = true;
      isFetchingMoreTags = true;
      errorMessage = '';
    });

    try {
      final response = await client.get(
        Uri.https(baseURL, '/api/v1/tasks/get-tags', {
          'search': search,
          'page': '$page',
          'limit': '$limit',
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      final dataBody = jsonDecode(response.body);

      if (response.statusCode == 200 && dataBody["success"] == true) {
        final List newTag = dataBody["data"];
        final bool serverHasMore =
            dataBody["data"].isNotEmpty &&
            (dataBody["data"].last["haveMore"] ?? false);

        setState(() {
          if (page == 1) {
            tags = newTag;
          } else {
            tags.addAll(newTag);
          }
          isLoading = false;
          haveMoreTags = serverHasMore;
          isFetchingMoreTags = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isFetchingMoreTags = false;
          errorMessage = dataBody["message"] ?? 'Failed to load Tag';
        });
      }
    } catch (e) {
      debugPrint("ERROR:" + e.toString());
      setState(() {
        isLoading = false;
        isFetchingMoreTags = false;
        errorMessage = 'An error occurred: $e';
      });
    }
  }

  Future<void> addTag(Map<String, dynamic> TagData) async {
    try {
      final response = await client.post(
        Uri.https(baseURL, '/api/v1/tasks/add-tag'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(TagData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        fetchTags();
      } else {
        var dataBody = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                dataBody["status"] == false && dataBody["msg"] != null
                    ? Text(dataBody["msg"])
                    : Text('Failed to add Tag'),
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

  Future<void> deleteTag(String tagName) async {
    bool? confirmDelete = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Tag'),
            content: const Text('Are you sure you want to delete this tag?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Yes'),
              ),
            ],
          ),
    );

    if (confirmDelete == true) {
      try {
        final response = await client.delete(
          Uri.https(baseURL, '/api/v1/tasks/remove-tag/$tagName'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tag deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          fetchTags();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete tag'),
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

  void showAddTagsDialog() {
    final TextEditingController tagNameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Tags 🏷️'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tagNameController,
                  decoration: InputDecoration(labelText: 'Your Tag Name'),
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
                  addTag({'tag_name': tagNameController.text});
                  Navigator.of(context).pop();
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
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
    debugPrint(project.toString());
    final TextEditingController projectNameController = TextEditingController(
      text: project["name"],
    );
    final TextEditingController projectDescriptionController =
        TextEditingController(text: project["description"]);

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects & Tags'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Projects'), Tab(text: 'Tags')],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Search Field
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText:
                      _tabController.index == 0
                          ? 'Search Projects...'
                          : 'Search Tags...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                ),
              ),
              const SizedBox(height: 12),
              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Projects Tab
                    _buildProjectsTab(theme),
                    // Tags Tab
                    _buildTagsTab(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedFab(onPressed: showAddProjectDialog, text: 'Add Project'),
          const SizedBox(height: 8),
          AnimatedFab(onPressed: showAddTagsDialog, text: 'Add Tags'),
        ],
      ),
    );
  }

  Widget _buildProjectsTab(ThemeData theme) {
    if (isLoading && currentProjectsPage == 1) {
      return const Center(child: CircularProgressIndicator());
    } else if (errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          errorMessage,
          style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
        ),
      );
    } else if (projects.isEmpty) {
      return const Center(child: Text('No projects found.'));
    } else {
      return ListView.separated(
        controller: _projectsScrollController,
        itemCount: projects.length + (haveMoreProjects ? 1 : 0),
        physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == projects.length) {
            return const Center(child: CircularProgressIndicator());
          }

          final project = projects[index];
          final projectID = project["projectID"];

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            color: theme.cardColor,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: theme.primaryColorLight,
                child: Text('${index + 1}'),
              ),
              title: Text(
                project["name"] ?? 'No Name',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                project["description"] ?? 'No Description',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed:
                    () => deleteProject(projectID).then((_) {
                      setState(() {
                        currentProjectsPage = 1;
                        projects.clear();
                        fetchProjects();
                      });
                    }),
              ),
              onTap:
                  () => Navigator.pushNamed(
                    context,
                    '/taskByProjects',
                    arguments: {"projectID": projectID, ...project},
                  ),
              onLongPress: () => showEditProjectDialog(project),
            ),
          );
        },
      );
    }
  }

  Widget _buildTagsTab(ThemeData theme) {
    if (isLoading && currentTagsPage == 1) {
      return const Center(child: CircularProgressIndicator());
    } else if (errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          errorMessage,
          style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
        ),
      );
    } else if (tags.isEmpty) {
      return const Center(child: Text('No tags found.'));
    } else {
      return ListView.separated(
        controller: _tagsScrollController,
        itemCount: tags.length + (haveMoreTags ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == tags.length) {
            return const Center(child: CircularProgressIndicator());
          }

          final tag = tags[index];
          final tagName = tag["tag_name"];

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            color: theme.cardColor,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: theme.primaryColorLight,
                child: const Icon(Icons.tag),
              ),
              title: Text(
                tagName ?? 'No Name',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed:
                    () => deleteTag(tagName).then((_) {
                      setState(() {
                        currentTagsPage = 1;
                        tags.clear();
                        fetchTags();
                      });
                    }),
              ),
            ),
          );
        },
      );
    }
  }
}
