import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import '../models/favorites_model.dart';
import 'favorites_page.dart';
import 'package:path_provider/path_provider.dart';

class FavoritesHomePage extends StatefulWidget {
  const FavoritesHomePage({super.key});

  @override
  State<FavoritesHomePage> createState() => _MyHomePageContentState();
}

class _MyHomePageContentState extends State<FavoritesHomePage> {
  late StreamSubscription _intentSub;
  // ignore: unused_field
  List<SharedMediaFile> _pendingSharedFiles = [];

  @override
  void initState() {
    super.initState();

    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        setState(() => _pendingSharedFiles = value);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleSharedFiles(value);
        });
      }
    });

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) _handleSharedFiles(value);
      },
      onError: (err) => debugPrint("Error receiving shared files: $err"),
    );
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    for (var file in files) {
      debugPrint("Shared file path: ${file.path}");
      String? customName = await _showNameDialog(context);
      if (customName != null && customName.isNotEmpty && mounted) {
        context.read<FavoritesModel>().addFavorite((file.path, customName));
      }
    }
    ReceiveSharingIntent.instance.reset();
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  Future<(String, String)?> _showTextInputDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final contentController = TextEditingController();

    return showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Text Note'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              decoration: InputDecoration(
                labelText: 'Content',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Icon(Icons.notes),
                ),
              ),
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, (name, contentController.text));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showNameDialog(BuildContext context,
      {String? initialName}) async {
    final TextEditingController controller =
        TextEditingController(text: initialName);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialName == null ? 'Name this file' : 'Rename file'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter name',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.drive_file_rename_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.star_rounded, color: colorScheme.primary, size: 28),
            const SizedBox(width: 8),
            Text(
              'Favorites',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _LegendRow(),
          ),
        ],
      ),
      body: const FavoritesPage(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddPressed(context),
        elevation: 4,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _onAddPressed(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add to Favorites',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black54),
                  ),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child:
                      Icon(Icons.text_fields, color: Colors.green.shade700),
                ),
                title: const Text('Text Note',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Write a new note'),
                onTap: () => Navigator.pop(context, 'text'),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.attach_file, color: Colors.blue.shade700),
                ),
                title: const Text('File',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pick from your device'),
                onTap: () => Navigator.pop(context, 'file'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'text') {
      // ignore: use_build_context_synchronously
      final result = await _showTextInputDialog(context);
      if (result != null) {
        final name = result.$1;
        final content = result.$2;
        final dir = await getApplicationDocumentsDirectory();
        final filePath =
            '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.txt';
        await File(filePath).writeAsString(content);
        // ignore: use_build_context_synchronously
        context.read<FavoritesModel>().addFavorite((filePath, name));
      }
    } else {
      try {
        FilePickerResult? result =
            await FilePicker.platform.pickFiles(type: FileType.any);
        if (result != null) {
          String? filePath = result.files.single.path;
          String? fileName = result.files.single.name;
          // ignore: use_build_context_synchronously
          String? customName = await _showNameDialog(context);
          if (customName != null && customName.isNotEmpty) {
            // ignore: use_build_context_synchronously
            context
                .read<FavoritesModel>()
                .addFavorite((filePath, customName));
            debugPrint(
                'Selected file: $fileName at $filePath with name: $customName');
          }
        }
      } catch (e) {
        debugPrint('Error picking file: $e');
      }
    }
  }
}

/// Small coloured dots legend shown in the app bar.
class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(const Color(0xFFE53935)),
        _dot(const Color(0xFF43A047)),
        _dot(const Color(0xFF1E88E5)),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
