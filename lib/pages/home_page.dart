import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import '../models/folders_model.dart';
import '../models/favorites_model.dart';
import 'folders_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _MyHomePageContentState();
}

class _MyHomePageContentState extends State<HomePage> {
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
      // ignore: use_build_context_synchronously
      final folderId = await _showFolderPickerDialog(context);
      if (folderId == null) continue;

      // ignore: use_build_context_synchronously
      String? customName = await _showNameDialog(context);
      if (customName != null && customName.isNotEmpty) {
        await FavoritesModel.addFavoriteDirectly(folderId, file.path, customName);
      }
    }
    ReceiveSharingIntent.instance.reset();
  }

  Future<int?> _showFolderPickerDialog(BuildContext context) async {
    final model = context.read<FoldersModel>();

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose a Folder'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: model.folders.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No folders yet. Create a folder first.'),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: model.folders.length,
                  itemBuilder: (context, index) {
                    final (folderId, folderName) = model.folders[index];
                    return ListTile(
                      leading: const Icon(Icons.folder_rounded, color: Color(0xFFD4A574)),
                      title: Text(folderName ?? 'Unnamed'),
                      onTap: () => Navigator.pop(context, folderId),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  Future<String?> _showNameDialog(BuildContext context,
      {String? initialName}) async {
    final TextEditingController controller =
        TextEditingController(text: initialName);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialName == null ? 'Name this folder' : 'Rename folder'),
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
            Icon(Icons.folder, color: Color.fromARGB(255, 102, 94, 90), size: 28),
            const SizedBox(width: 8),
            Text(
              'Folders',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 102, 94, 90),
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12)
          ),
        ],
      ),
      body: const FoldersPage(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddPressed(context),
        elevation: 4,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _onAddPressed(BuildContext context) async {
     String? customName = await _showNameDialog(context);
          if (customName != null && customName.isNotEmpty) {
            // ignore: use_build_context_synchronously
            context
                .read<FoldersModel>()
                .addFolder(customName);
            debugPrint(
                'Created new folder with name: $customName');
          }
  }
}

