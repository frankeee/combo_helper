import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_shelf/models/favorites_model.dart';

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

  Future<FavoritesModel> buildModel({int folderIndex = 0}) async {
    final model = FavoritesModel(folderIndex: folderIndex);
    await Future.delayed(Duration.zero);
    return model;
  }

  const fav1 = (0, '/path/a.mp3', 'Song One');
  const fav2 = (0, '/path/b.txt', 'My Note');
  const fav3 = (0, '/path/c.png', 'Beach Photo');

  // ── Construction ───────────────────────────────────────────────────────────

  group('FavoritesModel – construction', () {
    test('starts with empty favorites list', () async {
      final model = await buildModel();
      expect(model.favorites, isEmpty);
    });

    test('current is -1 initially', () async {
      final model = await buildModel();
      expect(model.current, equals(-1));
    });

    test('editingIndex is -1 initially', () async {
      final model = await buildModel();
      expect(model.editingIndex, equals(-1));
    });

    test('loads only favorites belonging to the given folderIndex', () async {
      SharedPreferences.setMockInitialValues({
        'favorites': jsonEncode([
          {'folderId': 0, 'path': '/a.mp3', 'name': 'InFolder0'},
          {'folderId': 1, 'path': '/b.mp3', 'name': 'InFolder1'},
        ]),
      });
      final model = await buildModel(folderIndex: 0);
      expect(model.favorites.length, equals(1));
      expect(model.favorites.first.$3, equals('InFolder0'));
    });

    test('ignores favorites from other folders', () async {
      SharedPreferences.setMockInitialValues({
        'favorites': jsonEncode([
          {'folderId': 99, 'path': '/x.mp3', 'name': 'Alien'},
        ]),
      });
      final model = await buildModel(folderIndex: 0);
      expect(model.favorites, isEmpty);
    });

    test('handles malformed JSON without crashing', () async {
      SharedPreferences.setMockInitialValues({'favorites': '!!BAD_JSON!!'});
      expect(() async => await buildModel(), returnsNormally);
    });
  });

  // ── addFavorite ────────────────────────────────────────────────────────────

  group('FavoritesModel – addFavorite', () {
    test('adds item to the list', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      expect(model.favorites.length, equals(1));
      expect(model.favorites.first, equals(fav1));
    });

    test('multiple favorites accumulate in order', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      model.addFavorite(fav2);
      model.addFavorite(fav3);
      expect(model.favorites, equals([fav1, fav2, fav3]));
    });

    test('notifies listeners', () async {
      final model = await buildModel();
      var notified = false;
      model.addListener(() => notified = true);
      model.addFavorite(fav1);
      expect(notified, isTrue);
    });

    test('persists to SharedPreferences', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      await Future.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('favorites')!) as List;
      expect(decoded.any((e) => e['name'] == 'Song One'), isTrue);
    });

    test('adding same item twice results in two entries', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      model.addFavorite(fav1);
      expect(model.favorites.length, equals(2));
    });
  });

  // ── removeFavorite ─────────────────────────────────────────────────────────

  group('FavoritesModel – removeFavorite', () {
    test('removes the correct item', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      model.addFavorite(fav2);
      await model.removeFavorite(fav1);
      expect(model.favorites.contains(fav1), isFalse);
      expect(model.favorites.contains(fav2), isTrue);
    });

    test('list length decreases by 1', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      model.addFavorite(fav2);
      await model.removeFavorite(fav1);
      expect(model.favorites.length, equals(1));
    });

    test('removing non-existent item is a no-op', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      await model.removeFavorite(fav2);
      expect(model.favorites.length, equals(1));
    });

    test('notifies listeners', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      var count = 0;
      model.addListener(() => count++);
      await model.removeFavorite(fav1);
      expect(count, greaterThanOrEqualTo(1));
    });

    test('removal is persisted', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      await Future.delayed(Duration.zero);
      await model.removeFavorite(fav1);
      await Future.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('favorites') ?? '[]') as List;
      expect(decoded.any((e) => e['name'] == 'Song One'), isFalse);
    });
  });

  // ── renameFavorite ─────────────────────────────────────────────────────────

 group('FavoritesModel – renameFavorite', () {
  test('updates the name field', () async {
    final model = await buildModel();
    model.addFavorite(fav1);
    model.renameFavorite(fav1, 'Renamed Song', '/new/path.mp3');
    expect(model.favorites.first.$3, equals('Renamed Song'));
  });

  test('preserves folderId and updates filePath after rename', () async {
    final model = await buildModel();
    model.addFavorite(fav1);
    model.renameFavorite(fav1, 'NewName', '/new/path.mp3');
    final renamed = model.favorites.first;
    expect(renamed.$1, equals(fav1.$1));       // folderId unchanged
    expect(renamed.$2, equals('/new/path.mp3')); // filePath replaced by newPath
  });

  test('does nothing when item not found', () async {
    final model = await buildModel();
    model.addFavorite(fav1);
    model.renameFavorite(fav2, 'ShouldNotAppear', '/irrelevant.mp3');
    expect(model.favorites.first.$3, equals('Song One'));
  });

  test('does nothing when path is null', () async {
    final model = await buildModel();
    const nullPath = (0, null, 'NullPath');
    model.addFavorite(nullPath);
    model.renameFavorite(nullPath, 'NewName', '/irrelevant.mp3');
    expect(model.favorites.first.$3, equals('NullPath'));
  });

  test('does nothing when name is null', () async {
    final model = await buildModel();
    const nullName = (0, '/path.mp3', null);
    model.addFavorite(nullName);
    model.renameFavorite(nullName, 'NewName', '/irrelevant.mp3');
    expect(model.favorites.first.$3, isNull);
  });

  test('notifies listeners', () async {
    final model = await buildModel();
    model.addFavorite(fav1);
    var count = 0;
    model.addListener(() => count++);
    model.renameFavorite(fav1, 'Ping', '/ping.mp3');
    expect(count, greaterThanOrEqualTo(1));
  });

  test('persists new name', () async {
    final model = await buildModel();
    model.addFavorite(fav1);
    model.renameFavorite(fav1, 'Persisted Name', '/persisted.mp3');
    await Future.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    final decoded = jsonDecode(prefs.getString('favorites')!) as List;
    expect(decoded.any((e) => e['name'] == 'Persisted Name'), isTrue);
  });
});
  // ── reorderFavorites ───────────────────────────────────────────────────────

  group('FavoritesModel – reorderFavorites', () {
    test('moves item forward', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      model.addFavorite(fav2);
      model.addFavorite(fav3);
      model.reorderFavorites(0, 3);
      expect(model.favorites.map((f) => f.$3).toList(),
          equals(['My Note', 'Beach Photo', 'Song One']));
    });

    test('moves item backward', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      model.addFavorite(fav2);
      model.addFavorite(fav3);
      model.reorderFavorites(2, 0);
      expect(model.favorites.map((f) => f.$3).toList(),
          equals(['Beach Photo', 'Song One', 'My Note']));
    });

    test('list length unchanged', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      model.addFavorite(fav2);
      model.reorderFavorites(0, 2);
      expect(model.favorites.length, equals(2));
    });

    test('notifies listeners', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      model.addFavorite(fav2);
      var count = 0;
      model.addListener(() => count++);
      model.reorderFavorites(0, 2);
      expect(count, greaterThanOrEqualTo(1));
    });
  });

  // ── setCurrent ─────────────────────────────────────────────────────────────

  group('FavoritesModel – setCurrent', () {
    test('updates current index', () async {
      final model = await buildModel();
      model.setCurrent(2);
      expect(model.current, equals(2));
    });

    test('can reset to -1', () async {
      final model = await buildModel();
      model.setCurrent(3);
      model.setCurrent(-1);
      expect(model.current, equals(-1));
    });

    test('notifies listeners', () async {
      final model = await buildModel();
      var notified = false;
      model.addListener(() => notified = true);
      model.setCurrent(0);
      expect(notified, isTrue);
    });
  });

  // ── setEditingIndex ────────────────────────────────────────────────────────

  group('FavoritesModel – setEditingIndex', () {
    test('updates editingIndex', () async {
      final model = await buildModel();
      model.setEditingIndex(5);
      expect(model.editingIndex, equals(5));
    });

    test('can reset to -1', () async {
      final model = await buildModel();
      model.setEditingIndex(1);
      model.setEditingIndex(-1);
      expect(model.editingIndex, equals(-1));
    });

    test('notifies listeners', () async {
      final model = await buildModel();
      var notified = false;
      model.addListener(() => notified = true);
      model.setEditingIndex(0);
      expect(notified, isTrue);
    });
  });

  // ── getSliderPosition / setSliderPosition ──────────────────────────────────

  group('FavoritesModel – slider positions', () {
    test('returns 0.0 for unknown index', () async {
      final model = await buildModel();
      expect(model.getSliderPosition(99), equals(0.0));
    });

    test('stores and retrieves a slider position', () async {
      final model = await buildModel();
      await model.setSliderPosition(2, 0.75);
      expect(model.getSliderPosition(2), equals(0.75));
    });

    test('different indices are independent', () async {
      final model = await buildModel();
      await model.setSliderPosition(0, 0.1);
      await model.setSliderPosition(1, 0.9);
      expect(model.getSliderPosition(0), equals(0.1));
      expect(model.getSliderPosition(1), equals(0.9));
    });

    test('overwriting takes the new value', () async {
      final model = await buildModel();
      await model.setSliderPosition(0, 0.3);
      await model.setSliderPosition(0, 0.8);
      expect(model.getSliderPosition(0), equals(0.8));
    });

    test('setSliderPosition notifies listeners', () async {
      final model = await buildModel();
      var notified = false;
      model.addListener(() => notified = true);
      await model.setSliderPosition(0, 0.5);
      expect(notified, isTrue);
    });

    test('slider positions are not persisted (in-memory only)', () async {
      final model = await buildModel();
      await model.setSliderPosition(0, 0.5);
      final reload = await buildModel();
      expect(reload.getSliderPosition(0), equals(0.0));
    });
  });

  // ── Per-folder data isolation ──────────────────────────────────────────────

  group('FavoritesModel – folder isolation', () {
    test('favorites added to folder 0 are invisible to folder 1', () async {
      final m0 = await buildModel(folderIndex: 0);
      m0.addFavorite((0, '/a.mp3', 'OnlyInZero'));
      await Future.delayed(Duration.zero);
      final m1 = await buildModel(folderIndex: 1);
      expect(m1.favorites.any((f) => f.$3 == 'OnlyInZero'), isFalse);
    });

    test('two folder models hold independent favorites', () async {
      final m0 = await buildModel(folderIndex: 0);
      final m1 = await buildModel(folderIndex: 1);
      m0.addFavorite((0, '/x.mp3', 'InZero'));
      m1.addFavorite((1, '/y.mp3', 'InOne'));
      await Future.delayed(Duration.zero);

      final r0 = await buildModel(folderIndex: 0);
      final r1 = await buildModel(folderIndex: 1);
      expect(r0.favorites.length, equals(1));
      expect(r0.favorites.first.$3, equals('InZero'));
      expect(r1.favorites.length, equals(1));
      expect(r1.favorites.first.$3, equals('InOne'));
    });

    test('concurrent writes from two models do not corrupt each other', () async {
      final f0 = await buildModel(folderIndex: 0);
      final f1 = await buildModel(folderIndex: 1);
      f0.addFavorite((0, '/p0a.mp3', 'F0-A'));
      f1.addFavorite((1, '/p1a.mp3', 'F1-A'));
      await Future.delayed(Duration.zero);
      f0.addFavorite((0, '/p0b.mp3', 'F0-B'));
      f1.addFavorite((1, '/p1b.mp3', 'F1-B'));
      await Future.delayed(Duration.zero);

      final r0 = await buildModel(folderIndex: 0);
      final r1 = await buildModel(folderIndex: 1);
      expect(r0.favorites.map((f) => f.$3).toSet(), equals({'F0-A', 'F0-B'}));
      expect(r1.favorites.map((f) => f.$3).toSet(), equals({'F1-A', 'F1-B'}));
    });
  });

  // ── Persistence round-trip ─────────────────────────────────────────────────

  group('FavoritesModel – persistence round-trip', () {
    test('favorites survive a model reload', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      await Future.delayed(Duration.zero);
      final reload = await buildModel();
      expect(reload.favorites.any((f) => f.$3 == 'Song One'), isTrue);
    });

    test('rename survives reload', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      model.renameFavorite(fav1, 'AfterRename', "");
      await Future.delayed(Duration.zero);
      final reload = await buildModel();
      expect(reload.favorites.any((f) => f.$3 == 'AfterRename'), isTrue);
    });

    test('removal survives reload', () async {
      final model = await buildModel();
      model.addFavorite(fav1);
      model.addFavorite(fav2);
      await Future.delayed(Duration.zero);
      await model.removeFavorite(fav1);
      await Future.delayed(Duration.zero);
      final reload = await buildModel();
      expect(reload.favorites.any((f) => f.$3 == 'Song One'), isFalse);
      expect(reload.favorites.any((f) => f.$3 == 'My Note'), isTrue);
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('FavoritesModel – edge cases', () {
    test('operations on empty model do not throw', () async {
      final model = await buildModel();
      expect(() async => await model.removeFavorite(fav1), returnsNormally);
      expect(() => model.renameFavorite(fav1, 'X', ""), returnsNormally);
    });
  });
}
