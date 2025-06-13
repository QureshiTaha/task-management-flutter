import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:task_management/utils/permissionHandler.dart';

void openFullImage(BuildContext context, String imageUrl) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => FullImageViewer(imageUrl: imageUrl)),
  );
}

class FullImageViewer extends StatefulWidget {
  final String imageUrl;

  const FullImageViewer({super.key, required this.imageUrl});

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  bool _isSaving = false;

  Future<void> saveToGallery() async {
    setState(() => _isSaving = true);

    final hasPermission = await requestStoragePermission();

    if (!hasPermission) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'Please enable storage permission in settings to save images.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    openAppSettings();
                    Navigator.pop(context);
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
      );
      return;
    }

    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;
        final fileName = "chat_image_${DateTime.now().millisecondsSinceEpoch}";

        final result = await SaverGallery.saveImage(
          imageBytes,
          quality: 100,
          skipIfExists: true,
          fileName: fileName,
        );

        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isSuccess ? 'Saved to gallery!' : 'Failed to save',
            ),
          ),
        );
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load image')));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Full Image', style: TextStyle(color: Colors.white)),
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
            onPressed: _isSaving ? null : saveToGallery,
            tooltip: 'Save to Gallery',
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: widget.imageUrl,
          child: PhotoView(
            imageProvider: CachedNetworkImageProvider(widget.imageUrl),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder:
                (context, event) =>
                    const Center(child: CircularProgressIndicator()),
            errorBuilder:
                (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white70,
                    size: 60,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
