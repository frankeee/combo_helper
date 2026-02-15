import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import '../models/favorites_model.dart';
import 'favorites_page.dart';


class HomePage  extends StatefulWidget {
  const HomePage ({super.key});

  @override
  State<HomePage > createState() => _MyHomePageContentState();
}

class _MyHomePageContentState extends State<HomePage> {
  late StreamSubscription _intentSub;
  // ignore: unused_field
  List<SharedMediaFile> _pendingSharedFiles = [];

  @override
  void initState() {
    super.initState();
    
    // For files shared while app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        setState(() {
          _pendingSharedFiles = value;
        });
        // Handle after the first frame when context is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleSharedFiles(value);
        });
      }
    });

    // For files shared while app is running
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _handleSharedFiles(value);
        }
      },
      onError: (err) {
        debugPrint("Error receiving shared files: $err");
      },
    );
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    for (var file in files) {
      debugPrint("Shared file path: ${file.path}");
      
      // Ask user for a custom name
      String? customName = await _showNameDialog(context);
      
      if (customName != null && customName.isNotEmpty && mounted) {
        context.read<FavoritesModel>().addFavorite((file.path, customName));
      }
    }
    
    // Clear the shared files after processing
    ReceiveSharingIntent.instance.reset();
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  Future<String?> _showNameDialog(BuildContext context, {String? initialName}) async {
    final TextEditingController controller = TextEditingController(text: initialName);
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialName == null ? 'Name this file' : 'Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: const SafeArea(
                  child: FavoritesPage(),
                ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              try {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                );
                
                if (result != null) {
                  String? filePath = result.files.single.path;
                  String? fileName = result.files.single.name;
                  
                  // Ask user for a custom name
                  // ignore: use_build_context_synchronously
                  String? customName = await _showNameDialog(context);
                  
                  if (customName != null && customName.isNotEmpty) {
                    // ignore: use_build_context_synchronously
                    context.read<FavoritesModel>().addFavorite((filePath, customName));
                    debugPrint('Selected file: $fileName at $filePath with name: $customName');
                  }
                }
              } catch (e) {
                debugPrint('Error picking file: $e');
              }
            },
            child: const Icon(Icons.add),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      }
    );
  }
}