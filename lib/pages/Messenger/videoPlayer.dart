import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http show get;
import 'package:path_provider/path_provider.dart';
import 'package:task_management/utils/permissionHandler.dart';
import 'package:video_player/video_player.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerWidget({required this.videoUrl, super.key});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() => _isLoading = false);
        _controller.play();
      });

    _controller.addListener(() {
      if (_controller.value.isPlaying != _isPlaying) {
        setState(() => _isPlaying = _controller.value.isPlaying);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> saveVideo() async {
    setState(() => _isSaving = true);

    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage permission is required to save video.'),
        ),
      );
      return;
    }
    try {
      // Download video
      final response = await http.get(Uri.parse(widget.videoUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;

        // Save to temp file
        final tempDir = await getTemporaryDirectory();
        final tempPath =
            '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final file = File(tempPath);
        await file.writeAsBytes(bytes);

        // Save to gallery
        final result = await SaverGallery.saveFile(
          filePath: file.path,
          fileName: "task_chat_video_${DateTime.now().millisecondsSinceEpoch}",
          skipIfExists: true,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isSuccess
                  ? "Video saved to gallery"
                  : "Failed to save video",
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to download video")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Video', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Icon(Icons.download, color: Colors.white),
            tooltip: 'Save to Gallery',
            onPressed: _isSaving ? null : saveVideo,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: togglePlayPause,
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                  if (!_controller.value.isPlaying)
                    const Icon(
                      Icons.play_circle_outline,
                      size: 80,
                      color: Colors.white70,
                    ),
                ],
              ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Colors.blueAccent,
              backgroundColor: Colors.grey.shade700,
              bufferedColor: Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }
}
