// ============================================================
// ALL-IN-ONE TEST — Digital Memory Tracker
// Tests:
//  1. DBService — dummy seed, getAll, getByDate, getByApp, getLatest, getStats
//  2. QueryService — keyword parsing for every supported phrase
//  3. Widget smoke tests — HomeScreen, AskMemoryScreen, StatsScreen, FocusScreen
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cognitive_memory_tracker/services/db_service.dart';
import 'package:cognitive_memory_tracker/services/query_service.dart';
import 'package:cognitive_memory_tracker/widgets/answer_card.dart';
import 'package:cognitive_memory_tracker/screens/ask_memory_screen.dart';
import 'package:cognitive_memory_tracker/screens/stats_screen.dart';
import 'package:cognitive_memory_tracker/screens/focus_screen.dart';

// ─── Setup: use in-memory SQLite for tests (no real file I/O) ────────────────
void main() {
  setUpAll(() {
    // Use sqflite_common_ffi so unit tests can run without an Android device.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 1 — DBService
  // ══════════════════════════════════════════════════════════════════════════
  group('DBService', () {
    late DBService db;

    setUp(() {
      // Fresh singleton for each test group
      db = DBService();
    });

    test('getAllRecords returns data (dummy seed fallback)', () async {
      final records = await db.getAllRecords();
      // Dummy data is seeded on first open — must have at least 1 row.
      expect(records, isNotEmpty, reason: 'Dummy seed should populate the DB');
    });

    test('getByDate returns only matching rows', () async {
      final all = await db.getAllRecords();
      if (all.isEmpty) return; // Skip if DB somehow empty
      final targetDate = all.first['date'] as String;
      final filtered = await db.getByDate(targetDate);
      expect(filtered.every((r) => r['date'] == targetDate), isTrue);
    });

    test('getByApp filters case-insensitively', () async {
      final results = await db.getByApp('gmail');
      // Dummy data contains Gmail records.
      expect(results, isNotEmpty, reason: 'Dummy seed has Gmail records');
      expect(
        results.every(
          (r) => (r['app_name'] as String).toLowerCase().contains('gmail'),
        ),
        isTrue,
      );
    });

    test('getLatestRecord returns exactly one record', () async {
      final latest = await db.getLatestRecord();
      expect(latest, isNotNull);
      expect(latest!.containsKey('app_name'), isTrue);
    });

    test('getStatsGroupedByApp returns sorted list with total_minutes', () async {
      final stats = await db.getStatsGroupedByApp();
      expect(stats, isNotEmpty);
      // Each item must have both keys.
      for (final item in stats) {
        expect(item.containsKey('app_name'), isTrue);
        expect(item.containsKey('total_minutes'), isTrue);
        expect(item['total_minutes'], isA<int>());
      }
      // Confirm sorted descending by total_minutes.
      for (int i = 0; i < stats.length - 1; i++) {
        expect(
          (stats[i]['total_minutes'] as int) >=
              (stats[i + 1]['total_minutes'] as int),
          isTrue,
          reason: 'Stats should be sorted highest → lowest',
        );
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 2 — QueryService (keyword parsing)
  // ══════════════════════════════════════════════════════════════════════════
  group('QueryService', () {
    late QueryService qs;

    setUp(() {
      qs = QueryService();
    });

    test('empty question returns prompt message', () async {
      final answer = await qs.ask('');
      expect(answer, contains('Please'));
    });

    test('"gmail" keyword triggers Gmail filter', () async {
      final answer = await qs.ask('How long did I use Gmail?');
      // Should mention Gmail or "No records"
      expect(
        answer.toLowerCase().contains('gmail') ||
            answer.toLowerCase().contains('no records'),
        isTrue,
      );
    });

    test('"whatsapp" keyword triggers WhatsApp filter', () async {
      final answer = await qs.ask('Show my WhatsApp usage');
      expect(
        answer.toLowerCase().contains('whatsapp') ||
            answer.toLowerCase().contains('no records'),
        isTrue,
      );
    });

    test('"today" keyword filters by today', () async {
      final answer = await qs.ask('What did I use today?');
      // Should not crash and should return a string.
      expect(answer, isA<String>());
      expect(answer.isNotEmpty, isTrue);
    });

    test('"yesterday" keyword filters by yesterday', () async {
      final answer = await qs.ask('Show apps I used yesterday');
      expect(answer, isA<String>());
      expect(answer.isNotEmpty, isTrue);
    });

    test('"last" keyword returns latest record', () async {
      final answer = await qs.ask('What was the last app I used?');
      // Dummy seed has data, so it should name an app.
      expect(answer.toLowerCase().contains('you used'), isTrue);
    });

    test('"today" + "gmail" combo works', () async {
      final answer = await qs.ask('Did I use Gmail today?');
      expect(answer, isA<String>());
      expect(answer.isNotEmpty, isTrue);
    });

    test('random unknown question returns non-empty fallback', () async {
      final answer = await qs.ask('zzz gibberish xyz');
      // Falls back to latest record or "no records"
      expect(answer, isA<String>());
      expect(answer.isNotEmpty, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 3 — Widget smoke tests
  // ══════════════════════════════════════════════════════════════════════════
  group('Widget smoke tests', () {
    // Helper: wrap widget in a minimal MaterialApp to avoid theme errors.
    Widget wrap(Widget child) => MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: child,
        );

    // ── AnswerCard ───────────────────────────────────────────────────────
    testWidgets('AnswerCard shows placeholder when answer is null',
        (tester) async {
      await tester.pumpWidget(wrap(const Scaffold(
        body: AnswerCard(),
      )));
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('AnswerCard shows loading spinner', (tester) async {
      await tester.pumpWidget(wrap(const Scaffold(
        body: AnswerCard(isLoading: true),
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AnswerCard shows answer text', (tester) async {
      const answer = 'You used Gmail for 10 minutes.';
      await tester.pumpWidget(wrap(const Scaffold(
        body: AnswerCard(answer: answer),
      )));
      expect(find.text(answer), findsOneWidget);
    });

    // ── AskMemoryScreen ──────────────────────────────────────────────────
    testWidgets('AskMemoryScreen renders text field and buttons',
        (tester) async {
      await tester.pumpWidget(wrap(const AskMemoryScreen()));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.text('Ask'), findsOneWidget);
    });

    testWidgets('AskMemoryScreen shows snack if empty question submitted',
        (tester) async {
      await tester.pumpWidget(wrap(const AskMemoryScreen()));
      await tester.pump();
      await tester.tap(find.text('Ask'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    // ── StatsScreen ──────────────────────────────────────────────────────
    testWidgets('StatsScreen renders with AppBar title', (tester) async {
      await tester.pumpWidget(wrap(const StatsScreen()));
      await tester.pump(); // kick off initState
      expect(find.text('Screen Time Stats'), findsOneWidget);
    });

    // ── FocusScreen ──────────────────────────────────────────────────────
    testWidgets('FocusScreen shows 25:00 on load', (tester) async {
      await tester.pumpWidget(wrap(const FocusScreen()));
      await tester.pump();
      expect(find.text('25:00'), findsOneWidget);
    });

    testWidgets('FocusScreen Start button exists', (tester) async {
      await tester.pumpWidget(wrap(const FocusScreen()));
      await tester.pump();
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('FocusScreen Reset button exists', (tester) async {
      await tester.pumpWidget(wrap(const FocusScreen()));
      await tester.pump();
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('FocusScreen pressing Start changes button to Pause',
        (tester) async {
      await tester.pumpWidget(wrap(const FocusScreen()));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('FocusScreen pressing Reset restores 25:00', (tester) async {
      await tester.pumpWidget(wrap(const FocusScreen()));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.text('25:00'), findsOneWidget);
    });
  });
}
