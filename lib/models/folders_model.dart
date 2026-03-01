import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FoldersModel extends ChangeNotifier {
  final List<(int, String?)> _folders = [];
  bool _isLoaded = false;
  int _editingIndex = -1;
  int get editingIndex => _editingIndex;
  
  FoldersModel() {
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    if (_isLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? foldersJson = prefs.getString('folders');
      
      if (foldersJson != null) {
        final List<dynamic> decoded = jsonDecode(foldersJson);
        _folders.clear();
        for (var item in decoded) {
          _folders.add((item['id'] as int, item['name'] as String?));
        }
        _isLoaded = true;
        notifyListeners();
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }


  Future<void> _saveFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, Object?>> foldersList = _folders
          .map((item) => {'id': item.$1, 'name': item.$2})
          .toList();
      await prefs.setString('folders', jsonEncode(foldersList));
    } catch (e) {
      debugPrint('Error saving folders: $e');
    }
  }

  List<(int, String?)> get folders => _folders;

  void addFolder(String? name) {
    int maxId = 0;
    if (_folders.isNotEmpty){
      for ((int, String?)element in _folders){
        if(element.$1 > maxId){
          maxId = element.$1;
        }
      }
      maxId += 1;
    }
    _folders.add((maxId,name));
    _saveFolders();
    notifyListeners();
  }

  void removeFolder((int, String?) par) {
    _folders.remove(par);
    _saveFolders();
    notifyListeners();
  }

  void renameFolder((int, String?) par, String newName){

    var (folderId, fileName) = par;

    if (fileName != null ){
      final index = _folders.indexOf(par);
      if (index >= 0){
        var newPair = (folderId, newName);
        _folders[index] = newPair;
        _saveFolders();
        notifyListeners();
      }
    }
  }

  void reorderFolders(int oldIndex, int newIndex) {
    // Flutter passes newIndex as if the item is already removed,
    // so decrement when moving downward
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _folders.removeAt(oldIndex);
    _folders.insert(newIndex, item);
    _saveFolders();
    notifyListeners();
  }

  void setEditingIndex(int index) {
    _editingIndex = index;
    notifyListeners();
  }
}

