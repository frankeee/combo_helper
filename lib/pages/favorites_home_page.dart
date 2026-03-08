// ignore_for_file: unnecessary_underscores

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../models/favorites_model.dart';
import 'favorites_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FavoritesHomePage extends StatefulWidget {
  const FavoritesHomePage({
                            super.key,
                            required this.folderIndex,
                          });

  final int folderIndex;
  @override
  // ignore: no_logic_in_create_state
  State<FavoritesHomePage> createState() => _MyHomePageContentState(folderIndex:folderIndex);
}

class _MyHomePageContentState extends State<FavoritesHomePage> {
  _MyHomePageContentState({required this.folderIndex});

  final int folderIndex;
  String _searchQuery = '';

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
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.star_rounded, color: colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Favorites',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 200, // adjust to taste
              child: _SearchBar(onChanged: (q) => setState(() => _searchQuery = q),),
            ),
          ),
        ],
      ),
      body: FavoritesPage(folderIndex:folderIndex,
                          searchQuery: _searchQuery),
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
        context.read<FavoritesModel>().addFavorite((folderIndex, filePath, name));
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
            
            final sourceFile = File(filePath!);
            if (!await sourceFile.exists()) return;

            final appDir = await getApplicationDocumentsDirectory();
            final destPath = path.join(appDir.path, fileName);
            await sourceFile.copy(destPath);

            // ignore: use_build_context_synchronously
            context
                .read<FavoritesModel>()
                .addFavorite((folderIndex, destPath, customName));
            debugPrint(
                'Selected file: $fileName at $destPath with name: $customName');
          }
        }
      } catch (e) {
        debugPrint('Error picking file: $e');
      }
    }
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({this.onChanged});
  final ValueChanged<String>? onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.black45, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, value, __) => value.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _controller.clear();
                      widget.onChanged?.call('');
                    },
                    child: const Icon(Icons.close, color: Colors.black38, size: 18),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
