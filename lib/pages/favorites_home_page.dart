// ignore_for_file: unnecessary_underscores, no_logic_in_create_state

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../models/favorites_model.dart';
import '../widgets/search_bar.dart';
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
  State<FavoritesHomePage> createState() =>
      _MyHomePageContentState(folderIndex: folderIndex);
}

class _MyHomePageContentState extends State<FavoritesHomePage> {
  _MyHomePageContentState({required this.folderIndex});

  final int folderIndex;
  String _searchQuery = '';
  

String removeExtension(String fileName){


  int i = fileName.length - 1;

  while (0 <= i)
  {
    if (fileName[i] == ".")
    {
      break;
    }

    i--;
  }

  if (i == -1)
  {
    return fileName;
  }

  return fileName.substring(0,i);
}

  Future<(String, String)?> _showTextInputDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final contentController = TextEditingController();

    return showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Text Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(
                  Icons.label_outline_rounded,
                  color: Color(0xFFB0A49C),
                  size: 20,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Icon(
                    Icons.notes_rounded,
                    color: Color(0xFFB0A49C),
                    size: 20,
                  ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 80,
        iconTheme: const IconThemeData(
          color: Color(0xFF2C221E),
          size: 22,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0EBE6)),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.attach_file_rounded,
                color: Color(0xFFD4A574),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Files',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C221E),
                fontSize: 26,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
              width: 190,
              child: CustomSearchBar(
                  onChanged: (q) => setState(() => _searchQuery = q)),
            ),
          ),
        ],
      ),
      body: FavoritesPage(
        folderIndex: folderIndex,
        searchQuery: _searchQuery,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 40), // adjust this value as needed
        child: FloatingActionButton(
          onPressed: () => _onAddPressed(context),
          child: const Icon(Icons.add_rounded, size: 26),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          );
  }

  Future<void> _onAddPressed(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D8D2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add to Favorites',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFFB0A49C),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _BottomSheetOption(
                icon: Icons.text_fields_rounded,
                iconBg: Color(0xFFF0FAF4),
                iconColor: Color(0xFF4CAF7D),
                title: 'Text Note',
                subtitle: 'Write a new note',
                onTap: () => Navigator.pop(context, 'text'),
              ),
              const SizedBox(height: 4),
              _BottomSheetOption(
                icon: Icons.attach_file_rounded,
                iconBg: Color(0xFFEFF5FF),
                iconColor: Color(0xFF4A8EC2),
                title: 'File',
                subtitle: 'Pick from your device',
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
        context
            .read<FavoritesModel>()
            .addFavorite((folderIndex, filePath, name));
      }
    } else {
      try {
        FilePickerResult? result =
            await FilePicker.platform.pickFiles(type: FileType.any);
        if (result != null) {
          String? filePath = result.files.single.path;
          String? fileName = result.files.single.name;
          // ignore: use_build_context_synchronously
          String customName = removeExtension(fileName);
          if (customName.isNotEmpty) {
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

// ── Bottom sheet option tile ──────────────────────────────────────────────────

class _BottomSheetOption extends StatelessWidget {
  const _BottomSheetOption({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F1EE),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF2C221E),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A7A72),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB0A49C),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
