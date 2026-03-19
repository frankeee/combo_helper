import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_shelf/models/folders_model.dart';
import 'package:file_shelf/pages/folders_page.dart';

Widget makeTestApp(FoldersModel model, {String searchQuery = ''}) {
  return MaterialApp(
    home: ChangeNotifierProvider<FoldersModel>.value(
      value: model,
      child: Scaffold(body: FoldersPage(searchQuery: searchQuery)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FoldersModel> buildModel(WidgetTester tester) async {
    final model = FoldersModel();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    return model;
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  group('FoldersPage – empty state', () {
    testWidgets('shows empty-state icon when no folders', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
    });

    testWidgets('shows "No folders yet" text', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      expect(find.text('No folders yet'), findsOneWidget);
    });

    testWidgets('shows creation hint text', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      expect(find.text('Tap + to create your first folder'), findsOneWidget);
    });

    testWidgets('empty state disappears after adding a folder', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      model.addFolder('NewFolder');
      await tester.pumpAndSettle();
      expect(find.text('No folders yet'), findsNothing);
    });
  });

  // ── Folder list ────────────────────────────────────────────────────────────

  group('FoldersPage – folder list', () {
    testWidgets('renders a tile for every folder', (tester) async {
      final model = await buildModel(tester);
      model.addFolder('Alpha');
      model.addFolder('Beta');
      model.addFolder('Gamma');
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('list updates when a folder is added', (tester) async {
      final model = await buildModel(tester);
      model.addFolder('Existing');
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      model.addFolder('New');
      await tester.pumpAndSettle();
      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('list updates when a folder is removed', (tester) async {
      final model = await buildModel(tester);
      model.addFolder('DeleteMe');
      model.addFolder('KeepMe');
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      final toDelete = model.folders.firstWhere((f) => f.$2 == 'DeleteMe');
      await model.removeFolder(toDelete);
      await tester.pumpAndSettle();
      expect(find.text('DeleteMe'), findsNothing);
      expect(find.text('KeepMe'), findsOneWidget);
    });

    testWidgets('list updates when a folder is renamed', (tester) async {
      final model = await buildModel(tester);
      model.addFolder('OldName');
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      model.renameFolder(model.folders.first, 'NewName');
      await tester.pumpAndSettle();
      expect(find.text('OldName'), findsNothing);
      expect(find.text('NewName'), findsOneWidget);
    });

  });

  // ── Search ─────────────────────────────────────────────────────────────────

  group('FoldersPage – search', () {
    testWidgets('shows only matching folders', (tester) async {
      final model = await buildModel(tester);
      model.addFolder('Work');
      model.addFolder('Personal');
      model.addFolder('Workout');
      await tester.pumpWidget(makeTestApp(model, searchQuery: 'work'));
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('Personal'), findsNothing);
    });

    testWidgets('search is case-insensitive', (tester) async {
      final model = await buildModel(tester);
      model.addFolder('Holiday Photos');
      await tester.pumpWidget(makeTestApp(model, searchQuery: 'HOLIDAY'));
      await tester.pumpAndSettle();
      expect(find.text('Holiday Photos'), findsOneWidget);
    });

    testWidgets('shows "No results found" when nothing matches', (tester) async {
      final model = await buildModel(tester);
      model.addFolder('Alpha');
      await tester.pumpWidget(makeTestApp(model, searchQuery: 'zzz'));
      await tester.pumpAndSettle();
      expect(find.text('No results found'), findsOneWidget);
    });

    testWidgets('shows all folders when query is empty', (tester) async {
      final model = await buildModel(tester);
      model.addFolder('A');
      model.addFolder('B');
      model.addFolder('C');
      await tester.pumpWidget(makeTestApp(model, searchQuery: ''));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('partial match is sufficient', (tester) async {
      final model = await buildModel(tester);
      model.addFolder('My Vacation 2024');
      await tester.pumpWidget(makeTestApp(model, searchQuery: 'vaca'));
      await tester.pumpAndSettle();
      expect(find.text('My Vacation 2024'), findsOneWidget);
    });

    testWidgets('empty-folders state is NOT shown when search has no results', (tester) async {
      final model = await buildModel(tester);
      model.addFolder('Alpha');
      await tester.pumpWidget(makeTestApp(model, searchQuery: 'zzzz'));
      await tester.pumpAndSettle();
      expect(find.text('No folders yet'), findsNothing);
      expect(find.text('No results found'), findsOneWidget);
    });
  });

  // ── Reactive updates ───────────────────────────────────────────────────────

  group('FoldersPage – reactive updates', () {
    testWidgets('widget rebuilds reactively on model change', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      expect(find.text('No folders yet'), findsOneWidget);
      model.addFolder('Reactive Folder');
      await tester.pumpAndSettle();
      expect(find.text('Reactive Folder'), findsOneWidget);
      expect(find.text('No folders yet'), findsNothing);
    });

    testWidgets('five rapid adds all render', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        model.addFolder('Folder $i');
      }
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        expect(find.text('Folder $i'), findsOneWidget);
      }
    });
  });
}