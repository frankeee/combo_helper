import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_shelf/models/folders_model.dart';
import 'package:file_shelf/models/favorites_model.dart';
import 'package:flutter/services.dart';


void _mockAudioPlayers() {
    const channels = [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ];
    for (final name in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
  }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
  SharedPreferences.setMockInitialValues({});
  _mockAudioPlayers();
});

  Future<void> flush() => Future.delayed(Duration.zero);

  // ── Cross-model data isolation ─────────────────────────────────────────────

  group('Cross-model – data isolation', () {
    test('favorites added to folder 0 are invisible to folder 1', () async {
      final m0 = FavoritesModel(folderIndex: 0);
      await flush();
      m0.addFavorite((0, '/a.mp3', 'OnlyInZero'));
      await flush();
      final m1 = FavoritesModel(folderIndex: 1);
      await flush();
      expect(m1.favorites.any((f) => f.$3 == 'OnlyInZero'), isFalse);
    });


  
    test('two folder models hold independent favorites', () async {
      final m0 = FavoritesModel(folderIndex: 0);
      final m1 = FavoritesModel(folderIndex: 1);
      await flush();
      m0.addFavorite((0, '/x.mp3', 'InZero'));
      m1.addFavorite((1, '/y.mp3', 'InOne'));
      await flush();

      final r0 = FavoritesModel(folderIndex: 0);
      final r1 = FavoritesModel(folderIndex: 1);
      await flush();

      expect(r0.favorites.length, equals(1));
      expect(r0.favorites.first.$3, equals('InZero'));
      expect(r1.favorites.length, equals(1));
      expect(r1.favorites.first.$3, equals('InOne'));
    });

    test('removing a folder also removes its favorites from storage', () async {
      // Write a favorite for folder 0 to storage.
      final fav = FavoritesModel(folderIndex: 0);
      await flush();
      fav.addFavorite((0, '/keep.mp3', 'ToRemove'));
      await flush();

      // Now delete folder 0 via FoldersModel.
      final folders = FoldersModel();
      await flush();
      folders.addFolder('Folder0');
      await flush();
      await folders.removeFolder(folders.folders.first);
      await flush();

      // Reload FavoritesModel for folder 0 – should be empty.
      final reload = FavoritesModel(folderIndex: 0);
      await flush();
      expect(reload.favorites, isEmpty);
    });

    test('concurrent writes from two models do not corrupt each other', () async {
      final f0 = FavoritesModel(folderIndex: 0);
      final f1 = FavoritesModel(folderIndex: 1);
      await flush();
      f0.addFavorite((0, '/p0a.mp3', 'F0-A'));
      f1.addFavorite((1, '/p1a.mp3', 'F1-A'));
      await flush();
      f0.addFavorite((0, '/p0b.mp3', 'F0-B'));
      f1.addFavorite((1, '/p1b.mp3', 'F1-B'));
      await flush();

      final r0 = FavoritesModel(folderIndex: 0);
      final r1 = FavoritesModel(folderIndex: 1);
      await flush();

      expect(r0.favorites.map((f) => f.$3).toSet(), equals({'F0-A', 'F0-B'}));
      expect(r1.favorites.map((f) => f.$3).toSet(), equals({'F1-A', 'F1-B'}));
    });
  });

  // ── FoldersModel full lifecycle ────────────────────────────────────────────

  group('FoldersModel – full lifecycle', () {
    test('add → persist → reload preserves all folders', () async {
      final m1 = FoldersModel();
      await flush();
      m1.addFolder('Alpha');
      m1.addFolder('Beta');
      m1.addFolder('Gamma');
      await flush();

      final m2 = FoldersModel();
      await flush();
      expect(m2.folders.map((f) => f.$2).toList(), equals(['Alpha', 'Beta', 'Gamma']));
    });

    test('rename → persist → reload reflects new name', () async {
      final m1 = FoldersModel();
      await flush();
      m1.addFolder('OldName');
      await flush();
      m1.renameFolder(m1.folders.first, 'NewName');
      await flush();

      final m2 = FoldersModel();
      await flush();
      expect(m2.folders.first.$2, equals('NewName'));
    });

    test('delete → persist → reload does not contain deleted folder', () async {
      final m1 = FoldersModel();
      await flush();
      m1.addFolder('ToDelete');
      m1.addFolder('ToKeep');
      await flush();
      await m1.removeFolder(m1.folders.firstWhere((f) => f.$2 == 'ToDelete'));
      await flush();

      final m2 = FoldersModel();
      await flush();
      expect(m2.folders.any((f) => f.$2 == 'ToDelete'), isFalse);
      expect(m2.folders.any((f) => f.$2 == 'ToKeep'), isTrue);
    });

    test('reorder → persist → reload preserves new order', () async {
      final m1 = FoldersModel();
      await flush();
      m1.addFolder('X');
      m1.addFolder('Y');
      m1.addFolder('Z');
      await flush();
      m1.reorderFolders(0, 3); // X → end
      await flush();

      final m2 = FoldersModel();
      await flush();
      expect(m2.folders.map((f) => f.$2).toList(), equals(['Y', 'Z', 'X']));
    });

    test('ids are unique and stable across reloads', () async {
      final m1 = FoldersModel();
      await flush();
      m1.addFolder('A');
      m1.addFolder('B');
      m1.addFolder('C');
      final ids1 = m1.folders.map((f) => f.$1).toList();
      await flush();

      final m2 = FoldersModel();
      await flush();
      expect(m2.folders.map((f) => f.$1).toList(), equals(ids1));
      expect(ids1.toSet().length, equals(ids1.length));
    });
  });

  // ── FavoritesModel full lifecycle ──────────────────────────────────────────

  group('FavoritesModel – full lifecycle', () {
    test('add → persist → reload preserves all favorites', () async {
      final m1 = FavoritesModel(folderIndex: 0);
      await flush();
      m1.addFavorite((0, '/a.mp3', 'TrackA'));
      m1.addFavorite((0, '/b.txt', 'NoteB'));
      await flush();

      final m2 = FavoritesModel(folderIndex: 0);
      await flush();
      expect(m2.favorites.map((f) => f.$3).toSet(), equals({'TrackA', 'NoteB'}));
    });

    test('remove → persist → reload does not contain removed', () async {
      const fav = (0, '/del.mp3', 'DeletedTrack');
      final m1 = FavoritesModel(folderIndex: 0);
      await flush();
      m1.addFavorite(fav);
      await flush();
      await m1.removeFavorite(fav);
      await flush();

      final m2 = FavoritesModel(folderIndex: 0);
      await flush();
      expect(m2.favorites.any((f) => f.$3 == 'DeletedTrack'), isFalse);
    });
  });

  // ── FoldersModel id generation ─────────────────────────────────────────────

  group('FoldersModel – id generation', () {
    test('id not reused after deletion', () async {
      final model = FoldersModel();
      await flush();
      model.addFolder('A'); // id 0
      model.addFolder('B'); // id 1
      await model.removeFolder(model.folders.first); // remove id 0
      model.addFolder('C');
      final cId = model.folders.firstWhere((f) => f.$2 == 'C').$1;
      expect(cId, greaterThan(1));
    });

    test('100 folders all have unique ids', () async {
      final model = FoldersModel();
      await flush();
      for (var i = 0; i < 100; i++) {
        model.addFolder('Folder $i');
      }
      final ids = model.folders.map((f) => f.$1).toSet();
      expect(ids.length, equals(100));
    });
  });

  // ── Notification contracts ─────────────────────────────────────────────────

  group('ChangeNotifier – notification contracts', () {
    test('FoldersModel notifies once per addFolder', () async {
      final model = FoldersModel();
      await flush();
      var count = 0;
      model.addListener(() => count++);
      model.addFolder('X');
      expect(count, equals(1));
    });

    test('FoldersModel notifies once per setEditingIndex', () async {
      final model = FoldersModel();
      await flush();
      var count = 0;
      model.addListener(() => count++);
      model.setEditingIndex(0);
      expect(count, equals(1));
    });

    test('FavoritesModel notifies once per addFavorite', () async {
      final model = FavoritesModel(folderIndex: 0);
      await flush();
      var count = 0;
      model.addListener(() => count++);
      model.addFavorite((0, '/a.mp3', 'A'));
      expect(count, equals(1));
    });

    test('FavoritesModel notifies once per removeFavorite', () async {
      final model = FavoritesModel(folderIndex: 0);
      await flush();
      const fav = (0, '/a.mp3', 'A');
      model.addFavorite(fav);
      var count = 0;
      model.addListener(() => count++);
      await model.removeFavorite(fav);
      expect(count, equals(1));
    });
  });

  // ── SharedPreferences JSON structure ──────────────────────────────────────

  group('Persistence – JSON structure', () {
    test('folders are stored with id and name keys', () async {
      final model = FoldersModel();
      await flush();
      model.addFolder('MyFolder');
      await flush();

      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('folders')!) as List;
      expect(decoded.first.containsKey('id'), isTrue);
      expect(decoded.first.containsKey('name'), isTrue);
      expect(decoded.first['name'], equals('MyFolder'));
    });

    test('favorites are stored with folderId, path and name keys', () async {
      final model = FavoritesModel(folderIndex: 0);
      await flush();
      model.addFavorite((0, '/my/file.mp3', 'My Track'));
      await flush();

      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('favorites')!) as List;
      expect(decoded.first.containsKey('folderId'), isTrue);
      expect(decoded.first.containsKey('path'), isTrue);
      expect(decoded.first.containsKey('name'), isTrue);
      expect(decoded.first['name'], equals('My Track'));
      expect(decoded.first['folderId'], equals(0));
    });
  });
}
