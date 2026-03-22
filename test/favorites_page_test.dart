import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_shelf/models/favorites_model.dart';
import 'package:file_shelf/pages/favorites_page.dart';
import 'package:flutter/services.dart';


// MockPlatformInterfaceMixin is what makes the platform interface actually
// accept the replacement. Without it the assignment is silently rejected
// and the real native channels are used instead.
class FakeAudioplayersPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements AudioplayersPlatformInterface {
  @override
  Future<void> create(String playerId) async {}
  @override
  Future<void> dispose(String playerId) async {}
  @override
  Future<int> pause(String playerId) async => 1;
  @override
  Future<int> stop(String playerId) async => 1;
  @override
  Future<int> resume(String playerId) async => 1;
  @override
  Future<int> seek(String playerId, Duration position) async => 1;
  @override
  Future<int> setVolume(String playerId, double volume) async => 1;
  @override
  Future<int> setPlaybackRate(String playerId, double playbackRate) async => 1;
  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}
  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}
  @override
  Stream<AudioEvent> getEventStream(String playerId) => const Stream.empty();
}

Widget makeTestApp(
  FavoritesModel model, {
  String searchQuery = '',
  int folderIndex = 0,
}) {
  return MaterialApp(
    home: ChangeNotifierProvider<FavoritesModel>.value(
      value: model,
      child: Scaffold(
        body: FavoritesPage(
          folderIndex: folderIndex,
          searchQuery: searchQuery,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioplayersPlatformInterface.instance = FakeAudioplayersPlatform();

    // GlobalAudioScope bypasses the platform interface and hits channels directly
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      MockStreamHandler.inline(onListen: (args, sink) {}, onCancel: (args) {}),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<FavoritesModel> buildModel(
    WidgetTester tester, {
    int folderIndex = 0,
    List<(int, String?, String?)> initial = const [],
  }) async {
    final model = FavoritesModel(folderIndex: folderIndex);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    for (final fav in initial) {
      model.addFavorite(fav);
    }
    return model;
  }

  const fav1 = (0, '/path/a.mp3', 'Song One');
  const fav2 = (0, '/path/b.txt', 'My Note');
  const fav3 = (0, '/path/c.png', 'Beach Photo');

  // ── Empty state ────────────────────────────────────────────────────────────

  group('FavoritesPage – empty state', () {
    testWidgets('shows empty-state icon when no favorites', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    });

    testWidgets('shows "No favorites yet" label', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      expect(find.text('No files yet'), findsOneWidget);
    });

    testWidgets('shows "Tap + to add files or notes" hint', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      expect(find.text('Tap + to add files or notes'), findsOneWidget);
    });

    testWidgets('empty state disappears after adding a favorite', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      model.addFavorite(fav1);
      await tester.pumpAndSettle();
      expect(find.text('No files yet'), findsNothing);
    });
  });

  // ── List rendering ─────────────────────────────────────────────────────────

  group('FavoritesPage – list rendering', () {
    testWidgets('renders one card per favorite', (tester) async {
      final model = await buildModel(tester, initial: [fav1, fav2, fav3]);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      expect(find.text('Song One'), findsOneWidget);
      expect(find.text('My Note'), findsOneWidget);
      expect(find.text('Beach Photo'), findsOneWidget);
    });

    testWidgets('list updates when a favorite is added', (tester) async {
      final model = await buildModel(tester, initial: [fav1]);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      model.addFavorite(fav2);
      await tester.pumpAndSettle();
      expect(find.text('My Note'), findsOneWidget);
    });

    testWidgets('list updates when a favorite is renamed', (tester) async {
      final model = await buildModel(tester, initial: [fav1]);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      model.renameFavorite(fav1, 'Renamed Track',"");
      await tester.pumpAndSettle();
      expect(find.text('Song One'), findsNothing);
      expect(find.text('Renamed Track'), findsOneWidget);
    });
  });

  // ── Search ─────────────────────────────────────────────────────────────────

  group('FavoritesPage – search', () {
    testWidgets('filters by query (case-insensitive)', (tester) async {
      final model = await buildModel(tester, initial: [fav1, fav2, fav3]);
      await tester.pumpWidget(makeTestApp(model, searchQuery: 'song'));
      await tester.pumpAndSettle();
      expect(find.text('Song One'), findsOneWidget);
      expect(find.text('My Note'), findsNothing);
      expect(find.text('Beach Photo'), findsNothing);
    });

    testWidgets('shows all favorites when query is empty', (tester) async {
      final model = await buildModel(tester, initial: [fav1, fav2, fav3]);
      await tester.pumpWidget(makeTestApp(model, searchQuery: ''));
      await tester.pumpAndSettle();
      expect(find.text('Song One'), findsOneWidget);
      expect(find.text('My Note'), findsOneWidget);
      expect(find.text('Beach Photo'), findsOneWidget);
    });

    testWidgets('shows "No matching results" for unmatched query', (tester) async {
      final model = await buildModel(tester, initial: [fav1, fav2, fav3]);
      await tester.pumpWidget(makeTestApp(model, searchQuery: 'zzz'));
      await tester.pumpAndSettle();
      expect(find.text('No results found'), findsOneWidget);
    });

    testWidgets('partial name match works', (tester) async {
      final model = await buildModel(tester, initial: [(0, '/a.mp3', 'Epic Guitar Solo')]);
      await tester.pumpWidget(makeTestApp(model, searchQuery: 'guitar'));
      await tester.pumpAndSettle();
      expect(find.text('Epic Guitar Solo'), findsOneWidget);
    });

    testWidgets('uppercase query matches lowercase name', (tester) async {
      final model = await buildModel(tester, initial: [(0, '/x.txt', 'beach notes')]);
      await tester.pumpWidget(makeTestApp(model, searchQuery: 'BEACH'));
      await tester.pumpAndSettle();
      expect(find.text('beach notes'), findsOneWidget);
    });

    testWidgets('empty-state icon is absent on search-no-result path', (tester) async {
      final model = await buildModel(tester, initial: [fav1]);
      await tester.pumpWidget(makeTestApp(model, searchQuery: 'zzz'));
      await tester.pumpAndSettle();
      expect(find.text('No files yet'), findsNothing);
      expect(find.text('No results found'), findsOneWidget);
    });
  });

  // ── Reactive updates ───────────────────────────────────────────────────────

  group('FavoritesPage – reactive updates', () {
    testWidgets('widget rebuilds when model changes', (tester) async {
      final model = await buildModel(tester);
      await tester.pumpWidget(makeTestApp(model));
      await tester.pumpAndSettle();
      expect(find.text('No files yet'), findsOneWidget);
      model.addFavorite(fav1);
      await tester.pumpAndSettle();
      expect(find.text('Song One'), findsOneWidget);
      expect(find.text('No files yet'), findsNothing);
    });

    
  });
}