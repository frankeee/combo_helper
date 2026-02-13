// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Favorites App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 123, 101, 160)),
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider(
        create: (_) => FavoritesModel(),
        child: const _MyHomePageContent(),
      ),
    );
  }
}

// ChangeNotifier class to manage favorites state
class FavoritesModel extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<(String?, String?)> _favorites = [];
  int _current = -1;
  int get current => _current;
  int _editingIndex = -1;
  int get editingIndex => _editingIndex;
  bool _isLoaded = false;
  final Map<int, double> _sliderPositions = {};
  Duration _totalDuration = Duration.zero;
  bool _transitioning = false;



  FavoritesModel() {
    _loadFavorites();
    _initAudioListeners();
  }

  Future<void> _loadFavorites() async {
    if (_isLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? favoritesJson = prefs.getString('favorites');
      
      if (favoritesJson != null) {
        final List<dynamic> decoded = jsonDecode(favoritesJson);
        _favorites.clear();
        for (var item in decoded) {
          _favorites.add((item['path'] as String?, item['name'] as String?));
        }
        _isLoaded = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  void _initAudioListeners() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (!_transitioning) _totalDuration = duration;
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (_transitioning) return; // <-- ignore all events during swap
      if (_current != -1 && _totalDuration.inMilliseconds > 0 && position.inMilliseconds > 0) {
        _sliderPositions[_current] =
            position.inMilliseconds / _totalDuration.inMilliseconds;
        notifyListeners();
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        _sliderPositions[_current] = 0.0;
        _current = -1;
        notifyListeners();
      }
    });
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, String?>> favoritesList = _favorites
          .map((item) => {'path': item.$1, 'name': item.$2})
          .toList();
      await prefs.setString('favorites', jsonEncode(favoritesList));
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  void setCurrent(int index) {
    _current = index;
    notifyListeners();
  }

  double getSliderPosition(int index) => _sliderPositions[index] ?? 0.0;

  Future<void> setSliderPosition(int index, double value) async {
    _sliderPositions[index] = value;
    if (index == _current && _totalDuration.inMilliseconds > 0) {
      await _audioPlayer.seek(Duration(
        milliseconds: (_totalDuration.inMilliseconds * value).round(),
      ));
    }
    notifyListeners();
  }
  
  List<(String?, String?)> get favorites => _favorites;

  void addFavorite((String?, String?) par) {
    _favorites.add(par);
    _saveFavorites();
    notifyListeners();
  }

  void removeFavorite((String?, String?) par) {
    _favorites.remove(par);
    _saveFavorites();
    notifyListeners();
  }

  void setEditingIndex(int index) {
    _editingIndex = index;
    notifyListeners();
  }

  void renameFavorite((String?, String?) par, String newName){

    var (filePath, fileName) = par;

    if (filePath != null && fileName != null ){
      final index = _favorites.indexOf(par);
      if (index >= 0){
        var newPair = (filePath, newName);
        _favorites[index] = newPair;
        _saveFavorites();
        notifyListeners();
      }
    }
  }

  void reorderFavorites(int oldIndex, int newIndex) {
    // Flutter passes newIndex as if the item is already removed,
    // so decrement when moving downward
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex, item);
    _saveFavorites();
    notifyListeners();
  }

  Future<void> playAudio((String?, String?) par, double startPosition, int index) async {
    var (filePath, fileName) = par;
    try {
      _transitioning = true; // block slider updates during swap

      await _audioPlayer.stop();
      _current = index;
      await _audioPlayer.setSourceDeviceFile(filePath!);

      final duration = await _audioPlayer.getDuration();
      if (duration != null) _totalDuration = duration;

      if (startPosition > 0.0 && _totalDuration.inMilliseconds > 0) {
        await _audioPlayer.seek(Duration(
          milliseconds: (_totalDuration.inMilliseconds * startPosition).round(),
        ));
      }

      _transitioning = false; // re-enable updates before resuming
      await _audioPlayer.resume();
      notifyListeners();
    } catch (e) {
      _transitioning = false; // always reset on error too
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
  }

  Future<void> shareAudio((String?, String?) par) async {
    var (filePath, fileName) = par;
    
    if (filePath != null) {
      try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Sharing: $fileName',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing file: $e');
    }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class _MyHomePageContent extends StatefulWidget {
  const _MyHomePageContent();

  @override
  State<_MyHomePageContent> createState() => _MyHomePageContentState();
}

class _MyHomePageContentState extends State<_MyHomePageContent> {
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
        title: Text(initialName == null ? 'Name this audio' : 'Rename audio'),
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
                  type: FileType.audio,
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

// FavoritesPage - no parameters needed!
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch the FavoritesModel for changes
    final model = context.watch<FavoritesModel>();
    
    if (model.favorites.isEmpty) {
      return const Center(
        child: Text('No favorites yet'),
      );
    }

    Widget _buildFavoriteItem(BuildContext context, FavoritesModel model, int index) {
      var (filePath, fileName) = model.favorites[index];
      bool isEditing = model.editingIndex == index;
      
      return ListTile(
        key: ValueKey(filePath! + fileName!),
        title: Center(
          child: isEditing
              ? TextField(
                  controller: TextEditingController(text: fileName),
                  autofocus: true,
                  textAlign: TextAlign.center,
                  onSubmitted: (newName) {
                    if (newName.isNotEmpty) {
                      model.renameFavorite((filePath, fileName), newName);
                    }
                    model.setEditingIndex(-1);
                  },
                  onTapOutside: (_) {
                    model.setEditingIndex(-1);
                  },
                )
              : GestureDetector(
                  onLongPress: () {
                    model.setEditingIndex(index);
                  },
                  child: Text(fileName),
                ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.delete, color: Colors.black),
          onPressed: () {
            model.removeFavorite((filePath, fileName));
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                model.current == index ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
              ),
              onPressed: () {
                if (model.current != index) {
                  model.playAudio(
                  (filePath, fileName),
                  model.getSliderPosition(index),
                  index,
                );
                } else {
                  model.pauseAudio();
                  model.setCurrent(-1);
                }
              },
            ),
            SizedBox(
              width: 100,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: Colors.black,
                  inactiveTrackColor: Colors.black26,
                  thumbColor: Colors.black,
                  overlayColor: Colors.black12,
                ),
                child: Slider(
                  value: model.getSliderPosition(index).clamp(0.0, 1.0),
                  onChanged: (value) => model.setSliderPosition(index, value),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.black),
              onPressed: () async {
                try {
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(filePath)],
                      subject: 'Sharing: $fileName',
                    ),
                  );
                } catch (e) {
                  debugPrint('Error sharing file: $e');
                }
              },
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle_rounded, color: Colors.black),
            ),
          ],
        ),
      );
    }


    return ReorderableListView.builder(
      itemCount: model.favorites.length,
      onReorder: (oldIndex, newIndex) {
        model.reorderFavorites(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        return _buildFavoriteItem(context, model, index);
      },
    );
  }
}