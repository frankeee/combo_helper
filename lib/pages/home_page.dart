import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import '../models/folders_model.dart';
import '../models/favorites_model.dart';
import '../widgets/search_bar.dart';
import 'folders_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _MyHomePageContentState();
}

class _MyHomePageContentState extends State<HomePage> {
  late StreamSubscription _intentSub;
  String _searchQuery = '';
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
      String? customName = await _showNameDialog("file", context);
      if (customName != null && customName.isNotEmpty) {
        await FavoritesModel.addFavoriteDirectly(
            folderId, file.path, customName);
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
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: model.folders.isEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'No folders yet. Create a folder first.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8A7A72),
                  ),
                ),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: model.folders.length,
                  itemBuilder: (context, index) {
                    final (folderId, folderName) = model.folders[index];
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EBE6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.folder_rounded,
                          color: Color(0xFFD4A574),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        folderName ?? 'Unnamed',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF2C221E),
                        ),
                      ),
                      onTap: () => Navigator.pop(context, folderId),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  Future<String?> _showNameDialog(String fileOrFolder, BuildContext context,
      {String? initialName}) async {
    final TextEditingController controller =
        TextEditingController(text: initialName);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            initialName == null ? 'Name this $fileOrFolder' : 'Rename $fileOrFolder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter name',
            prefixIcon: const Icon(
              Icons.drive_file_rename_outline_rounded,
              color: Color(0xFFB0A49C),
              size: 20,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFF0EBE6),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EBE6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.folder_rounded,
                color: Color(0xFFD4A574),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Folders',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C221E),
                fontSize: 20,
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
      body: FoldersPage(searchQuery: _searchQuery),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddPressed(context),
        child: const Icon(Icons.add_rounded, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _onAddPressed(BuildContext context) async {
    String? customName = await _showNameDialog("folder", context);
    if (customName != null && customName.isNotEmpty) {
      // ignore: use_build_context_synchronously
      context.read<FoldersModel>().addFolder(customName);
      debugPrint('Created new folder with name: $customName');
    }
  }
}
