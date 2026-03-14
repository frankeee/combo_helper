import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_shelf/models/folders_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FoldersModel> buildModel() async {
    final model = FoldersModel();
    await Future.delayed(Duration.zero);
    return model;
  }

  // ── Construction & loading ─────────────────────────────────────────────────

  group('FoldersModel – construction', () {
    test('starts with an empty folder list', () async {
      final model = await buildModel();
      expect(model.folders, isEmpty);
    });

    test('editingIndex starts at -1', () async {
      final model = await buildModel();
      expect(model.editingIndex, equals(-1));
    });

    test('loads persisted folders on creation', () async {
      SharedPreferences.setMockInitialValues({
        'folders': jsonEncode([
          {'id': 0, 'name': 'Alpha'},
          {'id': 1, 'name': 'Beta'},
        ]),
      });
      final model = await buildModel();
      expect(model.folders.length, equals(2));
      expect(model.folders[0], equals((0, 'Alpha')));
      expect(model.folders[1], equals((1, 'Beta')));
    });

    test('handles corrupt JSON gracefully', () async {
      SharedPreferences.setMockInitialValues({'folders': 'NOT_JSON'});
      expect(() async => await buildModel(), returnsNormally);
    });
  });

  // ── addFolder ──────────────────────────────────────────────────────────────

  group('FoldersModel – addFolder', () {
    test('first folder gets id 0', () async {
      final model = await buildModel();
      model.addFolder('Work');
      expect(model.folders.first.$1, equals(0));
      expect(model.folders.first.$2, equals('Work'));
    });

    test('second folder id is 1', () async {
      final model = await buildModel();
      model.addFolder('Work');
      model.addFolder('Personal');
      expect(model.folders[1].$1, equals(1));
    });

    test('ids increment from the current max, not list length', () async {
      final model = await buildModel();
      model.addFolder('A'); // id 0
      model.addFolder('B'); // id 1
      await model.removeFolder((0, 'A'));
      model.addFolder('C'); // max was 1 → new id = 2
      final ids = model.folders.map((f) => f.$1).toList();
      expect(ids, containsAll([1, 2]));
    });

    test('folder count increases by 1 each add', () async {
      final model = await buildModel();
      model.addFolder('Test');
      expect(model.folders.length, equals(1));
      model.addFolder('Test2');
      expect(model.folders.length, equals(2));
    });

    test('accepts null name', () async {
      final model = await buildModel();
      model.addFolder(null);
      expect(model.folders.first.$2, isNull);
    });

    test('notifies listeners', () async {
      final model = await buildModel();
      var notified = false;
      model.addListener(() => notified = true);
      model.addFolder('X');
      expect(notified, isTrue);
    });

    test('persists to SharedPreferences', () async {
      final model = await buildModel();
      model.addFolder('Persistent');
      await Future.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('folders')!) as List;
      expect(decoded.any((e) => e['name'] == 'Persistent'), isTrue);
    });
  });

  // ── removeFolder ───────────────────────────────────────────────────────────

  group('FoldersModel – removeFolder', () {
    test('removes the correct folder', () async {
      final model = await buildModel();
      model.addFolder('Alpha');
      model.addFolder('Beta');
      final alpha = model.folders.firstWhere((f) => f.$2 == 'Alpha');
      await model.removeFolder(alpha);
      expect(model.folders.any((f) => f.$2 == 'Alpha'), isFalse);
      expect(model.folders.any((f) => f.$2 == 'Beta'), isTrue);
    });

    test('list length decreases by 1', () async {
      final model = await buildModel();
      model.addFolder('A');
      model.addFolder('B');
      await model.removeFolder(model.folders.first);
      expect(model.folders.length, equals(1));
    });

    test('removing non-existent entry does not crash', () async {
      final model = await buildModel();
      expect(() async => await model.removeFolder((99, 'Ghost')), returnsNormally);
    });

    test('notifies listeners', () async {
      final model = await buildModel();
      model.addFolder('Delete me');
      var count = 0;
      model.addListener(() => count++);
      await model.removeFolder(model.folders.first);
      expect(count, greaterThanOrEqualTo(1));
    });
  });

  // ── renameFolder ───────────────────────────────────────────────────────────

  group('FoldersModel – renameFolder', () {
    test('updates the folder name in place', () async {
      final model = await buildModel();
      model.addFolder('Old Name');
      model.renameFolder(model.folders.first, 'New Name');
      expect(model.folders.first.$2, equals('New Name'));
    });

    test('preserves the folder id after rename', () async {
      final model = await buildModel();
      model.addFolder('Original');
      final id = model.folders.first.$1;
      model.renameFolder(model.folders.first, 'Renamed');
      expect(model.folders.first.$1, equals(id));
    });

    test('does nothing when folder not found', () async {
      final model = await buildModel();
      model.addFolder('Existing');
      model.renameFolder((999, 'Ghost'), 'New');
      expect(model.folders.first.$2, equals('Existing'));
    });

    test('does nothing when fileName is null', () async {
      final model = await buildModel();
      model.addFolder(null);
      model.renameFolder(model.folders.first, 'ShouldNotChange');
      expect(model.folders.first.$2, isNull);
    });

    test('notifies listeners', () async {
      final model = await buildModel();
      model.addFolder('A');
      var count = 0;
      model.addListener(() => count++);
      model.renameFolder(model.folders.first, 'B');
      expect(count, greaterThanOrEqualTo(1));
    });

    test('persists renamed value', () async {
      final model = await buildModel();
      model.addFolder('OldName');
      model.renameFolder(model.folders.first, 'NewName');
      await Future.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('folders')!) as List;
      expect(decoded.any((e) => e['name'] == 'NewName'), isTrue);
      expect(decoded.any((e) => e['name'] == 'OldName'), isFalse);
    });
  });

  // ── reorderFolders ─────────────────────────────────────────────────────────

  group('FoldersModel – reorderFolders', () {
    test('moves item forward', () async {
      final model = await buildModel();
      model.addFolder('A');
      model.addFolder('B');
      model.addFolder('C');
      model.reorderFolders(0, 3);
      expect(model.folders.map((f) => f.$2).toList(), ['B', 'C', 'A']);
    });

    test('moves item backward', () async {
      final model = await buildModel();
      model.addFolder('A');
      model.addFolder('B');
      model.addFolder('C');
      model.reorderFolders(2, 0);
      expect(model.folders.map((f) => f.$2).toList(), ['C', 'A', 'B']);
    });

    test('swaps adjacent items', () async {
      final model = await buildModel();
      model.addFolder('First');
      model.addFolder('Second');
      model.reorderFolders(0, 2);
      expect(model.folders[0].$2, equals('Second'));
      expect(model.folders[1].$2, equals('First'));
    });

    test('list length unchanged after reorder', () async {
      final model = await buildModel();
      model.addFolder('A');
      model.addFolder('B');
      model.addFolder('C');
      model.reorderFolders(0, 2);
      expect(model.folders.length, equals(3));
    });

    test('notifies listeners', () async {
      final model = await buildModel();
      model.addFolder('A');
      model.addFolder('B');
      var count = 0;
      model.addListener(() => count++);
      model.reorderFolders(0, 2);
      expect(count, greaterThanOrEqualTo(1));
    });
  });

  // ── setEditingIndex ────────────────────────────────────────────────────────

  group('FoldersModel – setEditingIndex', () {
    test('updates editingIndex', () async {
      final model = await buildModel();
      model.setEditingIndex(3);
      expect(model.editingIndex, equals(3));
    });

    test('can reset to -1', () async {
      final model = await buildModel();
      model.setEditingIndex(2);
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

  // ── Persistence round-trip ─────────────────────────────────────────────────

  group('FoldersModel – persistence round-trip', () {
    test('folders survive a model reload', () async {
      final model1 = await buildModel();
      model1.addFolder('Persisted');
      await Future.delayed(Duration.zero);
      final model2 = await buildModel();
      expect(model2.folders.any((f) => f.$2 == 'Persisted'), isTrue);
    });

    test('order is preserved across reload', () async {
      final model1 = await buildModel();
      model1.addFolder('X');
      model1.addFolder('Y');
      model1.addFolder('Z');
      await Future.delayed(Duration.zero);
      final model2 = await buildModel();
      expect(model2.folders.map((f) => f.$2).toList(), equals(['X', 'Y', 'Z']));
    });

    test('rename survives reload', () async {
      final model1 = await buildModel();
      model1.addFolder('OldName');
      model1.renameFolder(model1.folders.first, 'NewName');
      await Future.delayed(Duration.zero);
      final model2 = await buildModel();
      expect(model2.folders.first.$2, equals('NewName'));
    });

    test('removal survives reload', () async {
      final model1 = await buildModel();
      model1.addFolder('ToDelete');
      model1.addFolder('ToKeep');
      await Future.delayed(Duration.zero);
      final toDelete = model1.folders.firstWhere((f) => f.$2 == 'ToDelete');
      await model1.removeFolder(toDelete);
      await Future.delayed(Duration.zero);
      final model2 = await buildModel();
      expect(model2.folders.any((f) => f.$2 == 'ToDelete'), isFalse);
      expect(model2.folders.any((f) => f.$2 == 'ToKeep'), isTrue);
    });

    test('reorder survives reload', () async {
      final model1 = await buildModel();
      model1.addFolder('X');
      model1.addFolder('Y');
      model1.addFolder('Z');
      model1.reorderFolders(0, 3); // X → end
      await Future.delayed(Duration.zero);
      final model2 = await buildModel();
      expect(model2.folders.map((f) => f.$2).toList(), equals(['Y', 'Z', 'X']));
    });

    test('ids are stable across reloads', () async {
      final model1 = await buildModel();
      model1.addFolder('A');
      model1.addFolder('B');
      final ids1 = model1.folders.map((f) => f.$1).toList();
      await Future.delayed(Duration.zero);
      final model2 = await buildModel();
      expect(model2.folders.map((f) => f.$1).toList(), equals(ids1));
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('FoldersModel – edge cases', () {
    test('20 folders all have unique ids', () async {
      final model = await buildModel();
      for (var i = 0; i < 20; i++) {
        model.addFolder('Folder $i');
      }
      final ids = model.folders.map((f) => f.$1).toSet();
      expect(ids.length, equals(20));
    });

    test('id not reused after deletion', () async {
      final model = await buildModel();
      model.addFolder('A'); // id 0
      model.addFolder('B'); // id 1
      await model.removeFolder(model.folders.first);
      model.addFolder('C');
      final cId = model.folders.firstWhere((f) => f.$2 == 'C').$1;
      expect(cId, greaterThan(1));
    });

    test('notifies exactly once per addFolder call', () async {
      final model = await buildModel();
      var count = 0;
      model.addListener(() => count++);
      model.addFolder('X');
      expect(count, equals(1));
    });
  });
}
