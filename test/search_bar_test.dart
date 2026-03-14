import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_shelf/widgets/search_bar.dart';

Widget makeApp(ValueChanged<String>? onChanged) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: CustomSearchBar(onChanged: onChanged),
          ),
        ),
      ),
    );

void main() {
  // ── Rendering ──────────────────────────────────────────────────────────────

  group('AppSearchBar – rendering', () {
    testWidgets('shows search icon', (tester) async {
      await tester.pumpWidget(makeApp(null));
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows "Search" hint text', (tester) async {
      await tester.pumpWidget(makeApp(null));
      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('clear button is hidden when field is empty', (tester) async {
      await tester.pumpWidget(makeApp(null));
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('clear button appears when text is entered', (tester) async {
      await tester.pumpWidget(makeApp(null));
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  // ── onChanged callback ─────────────────────────────────────────────────────

  group('AppSearchBar – onChanged', () {
    testWidgets('calls onChanged when text is typed', (tester) async {
      String? received;
      await tester.pumpWidget(makeApp((q) => received = q));
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(received, equals('abc'));
    });

    testWidgets('calls onChanged with empty string when cleared', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(makeApp(calls.add));
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(calls.last, equals(''));
    });

    testWidgets('clear button disappears after clearing', (tester) async {
      await tester.pumpWidget(makeApp(null));
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('null onChanged does not crash on input', (tester) async {
      await tester.pumpWidget(makeApp(null));
      expect(
        () async => tester.enterText(find.byType(TextField), 'hi'),
        returnsNormally,
      );
    });

    testWidgets('null onChanged does not crash on clear', (tester) async {
      await tester.pumpWidget(makeApp(null));
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      expect(
        () async => tester.tap(find.byIcon(Icons.close)),
        returnsNormally,
      );
    });
  });

  // ── Multiple interactions ──────────────────────────────────────────────────

  group('AppSearchBar – multiple interactions', () {
    testWidgets('field can be re-filled after clearing', (tester) async {
      String? latest;
      await tester.pumpWidget(makeApp((q) => latest = q));
      await tester.enterText(find.byType(TextField), 'first');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'second');
      await tester.pump();
      expect(latest, equals('second'));
    });

    testWidgets('last value passed to onChanged matches current field text', (tester) async {
      String? latest;
      await tester.pumpWidget(makeApp((q) => latest = q));
      final field = find.byType(TextField);
      await tester.enterText(field, 'a');
      await tester.pump();
      await tester.enterText(field, 'ab');
      await tester.pump();
      await tester.enterText(field, 'abc');
      await tester.pump();
      expect(latest, equals('abc'));
    });
  });
}
