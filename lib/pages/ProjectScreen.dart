import 'package:flutter/material.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  @override
  Widget build(BuildContext context) {
    final arguments =
        (ModalRoute.of(context)?.settings.arguments ?? <String, dynamic>{})
            as Map;

    String projectID = arguments["projectID"] ?? "";
    debugPrint(projectID);
    return Scaffold(
      appBar: AppBar(title: const Text('Update Project')),
      body: Center(child: Text('🚧Project Update Screen 🚧')),
    );
  }
}
