import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class FavoritesModel extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<(int, String?, String?)> _favorites = [];
  int _current = -1;
  int get current => _current;
  int _editingIndex = -1;
  int get editingIndex => _editingIndex;
  bool _isLoaded = false;
  final Map<int, double> _sliderPositions = {};
  Duration _totalDuration = Duration.zero;
  bool _transitioning = false;
  final int folderIndex;
  final Map<String, Duration> _audioDurations = {};

  FavoritesModel({required this.folderIndex}) {
    _loadFavorites(folderIndex);
    _initAudioListeners();
  }

  Future<void> _loadFavorites(int targetFolderId) async {
    if (_isLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? favoritesJson = prefs.getString('favorites');
      
      if (favoritesJson != null) {
        final List<dynamic> decoded = jsonDecode(favoritesJson);
        _favorites.clear();
        for (var item in decoded) {
          var favorite = (item['folderId'] as int,item['path'] as String?, item['name'] as String?);
          if(favorite.$1 == targetFolderId){
            _favorites.add(favorite);
          }
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
      if (_transitioning) return;
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

      // Load ALL existing favorites (all folders)
      List<Map<String, Object?>> allFavorites = [];
      final String? existingJson = prefs.getString('favorites');
      if (existingJson != null) {
        final List<dynamic> decoded = jsonDecode(existingJson);
        // Keep entries that belong to OTHER folders
        allFavorites = decoded
            .where((item) => item['folderId'] != folderIndex)
            .map<Map<String, Object?>>((item) => {
                  'folderId': item['folderId'],
                  'path': item['path'],
                  'name': item['name'],
                })
            .toList();
      }

      // Add THIS folder's current entries
      final thisFolderItems = _favorites
          .map((item) => {'folderId': item.$1, 'path': item.$2, 'name': item.$3})
          .toList();
      allFavorites.addAll(thisFolderItems);

      await prefs.setString('favorites', jsonEncode(allFavorites));
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  Future<Duration> getAudioDuration(String filePath) async {
    if (_audioDurations.containsKey(filePath)) {
      return _audioDurations[filePath]!;
    }

    final player = AudioPlayer();
    try {
      await player.setSourceDeviceFile(filePath);
      final duration = await player.getDuration() ?? Duration.zero;
      _audioDurations[filePath] = duration;
      return duration;
    } catch (_) {
      return Duration.zero;
    } finally {
      await player.dispose();
    }
  }

  void setCurrent(int index) {
    _current = index;
    notifyListeners();
  }

  static Future<void> addFavoriteDirectly(int folderId, String path, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, Object?>> allFavorites = [];
      final String? existingJson = prefs.getString('favorites');
      if (existingJson != null) {
        final List<dynamic> decoded = jsonDecode(existingJson);
        allFavorites = decoded.map<Map<String, Object?>>((item) => {
          'folderId': item['folderId'],
          'path': item['path'],
          'name': item['name'],
        }).toList();
      }

      final sourceFile = File(path);
      if (!await sourceFile.exists()) return;
      final appDir = await getApplicationDocumentsDirectory();
      final ext = p.extension(path);
      final destPath = p.join(appDir.path, '$name$ext');
      await sourceFile.copy(destPath);

      allFavorites.add({'folderId': folderId, 'path': destPath, 'name': name});
      await prefs.setString('favorites', jsonEncode(allFavorites));
    } catch (e) {
      debugPrint('Error saving favorite: $e');
    }
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
  
  List<(int, String?, String?)> get favorites => _favorites;

  void addFavorite((int, String?, String?) par) {
    _favorites.add(par);
    _saveFavorites();
    notifyListeners();
  }

  Future<void> removeFavorite((int, String?, String?) par) async {
    var filePath = par.$2;
    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _favorites.remove(par);
    
    _saveFavorites();
    notifyListeners();
  }

  void setEditingIndex(int index) {
    _editingIndex = index;
    notifyListeners();
  }

  void renameFavorite((int, String?, String?) par, String newName){

    var (folderId, filePath, fileName) = par;

    if (filePath != null && fileName != null ){
      final index = _favorites.indexOf(par);
      if (index >= 0){
        var newPair = (folderId, filePath, newName);
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

