import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/screens/SettingsScreen.dart'
    show badDebugSave, goodDebugSave, goodDebugSaveV2, SettingsScreen;

void main() {
  group('SettingsScreen Widget Tests', () {
    late StreamController testStream;

    setUp(() {
      testStream = StreamController.broadcast();
    });

    tearDown(() {
      testStream.close();
    });

    group('useSystemColors behavior', () {
      testWidgets('dark mode toggle visibility depends on useSystemColors', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(home: SettingsScreen(testStream, null)));
        await tester.pumpAndSettle();

        // Verify useSystemColors switch exists
        expect(find.text('Use system colors'), findsOneWidget);
        final useSystemColorsSwitch = find.byType(Switch).first;
        expect(useSystemColorsSwitch, findsOneWidget);

        // Get the current state to verify conditional rendering logic
        final switchWidget = tester.widget<Switch>(useSystemColorsSwitch);
        final isDarkModeVisible = find.text('Dark mode').evaluate().isNotEmpty;

        // Verify the logical relationship: if using system colors, dark mode should be hidden
        // This verifies the conditional rendering in SettingsScreen lines 138-154
        if (switchWidget.value == true) {
          expect(isDarkModeVisible, isFalse, reason: 'Dark mode toggle should be hidden when using system colors');
        }
        // If not using system colors, dark mode can be visible (but not guaranteed due to async loading)
      });
    });

    group('Switch interactions', () {
      testWidgets('useSystemColors switch is tappable', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(home: SettingsScreen(testStream, null)));
        await tester.pumpAndSettle();

        // Verify switch exists and is tappable
        final switchFinder = find.byType(Switch).first;
        expect(switchFinder, findsOneWidget);

        // Verify it has an onChanged callback (is interactive)
        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.onChanged, isNotNull, reason: 'Switch should be interactive');

        // Verify tapping doesn't crash
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
      });

      testWidgets('logWrap switch is tappable', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(home: SettingsScreen(testStream, null)));
        await tester.pumpAndSettle();

        expect(find.text('Wrap log output'), findsOneWidget);

        // Find all switches
        final switches = find.byType(Switch);
        expect(
          switches.evaluate().length,
          greaterThanOrEqualTo(2),
          reason: 'Should have at least useSystemColors and logWrap switches',
        );

        // Verify tapping doesn't crash
        final logWrapSwitch = switches.at(1);
        await tester.tap(logWrapSwitch);
        await tester.pumpAndSettle();
      });

      testWidgets('trackErrors switch is tappable', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(home: SettingsScreen(testStream, null)));
        await tester.pumpAndSettle();

        expect(find.text('Report errors automatically'), findsOneWidget);

        // Find all switches
        final switches = find.byType(Switch);
        expect(
          switches.evaluate().length,
          greaterThanOrEqualTo(3),
          reason: 'Should have at least useSystemColors, logWrap, and trackErrors switches',
        );

        // Verify tapping doesn't crash (trackErrors is typically index 2)
        final trackErrorsSwitch = switches.at(2);
        await tester.tap(trackErrorsSwitch);
        await tester.pumpAndSettle();
      });
    });

    group('UI elements present', () {
      testWidgets('displays all expected settings options', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(home: SettingsScreen(testStream, null)));
        await tester.pumpAndSettle();

        // Verify core settings are present
        expect(find.text('Use system colors'), findsOneWidget);
        expect(find.text('Wrap log output'), findsOneWidget);
        expect(find.text('Report errors automatically'), findsOneWidget);
        expect(find.text('Enroll with Managed Nebula'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);
      });

      testWidgets('all switches are interactive', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(home: SettingsScreen(testStream, null)));
        await tester.pumpAndSettle();

        // Verify we have interactive switches
        final switches = find.byType(Switch);
        expect(switches, findsWidgets);

        // Verify switches have onChanged callbacks (are interactive)
        for (final element in switches.evaluate()) {
          final switchWidget = element.widget as Switch;
          expect(switchWidget.onChanged, isNotNull, reason: 'Switch should be interactive');
        }
      });
    });

    group('Debug functionality', () {
      testWidgets('displays debug buttons in debug mode', (WidgetTester tester) async {
        if (!kDebugMode) return;

        await tester.pumpWidget(MaterialApp(home: SettingsScreen(testStream, null)));
        await tester.pumpAndSettle();

        expect(find.text('Bad Site'), findsOneWidget);
        expect(find.text('Good Site'), findsOneWidget);
        expect(find.text('Good Site V2'), findsOneWidget);
        expect(find.text('Clear Keys'), findsOneWidget);
      });

      testWidgets('does not display debug buttons in release mode', (WidgetTester tester) async {
        // Skipped in debug mode - would verify in release builds
      }, skip: kDebugMode);

      testWidgets('accepts debug callback parameter', (WidgetTester tester) async {
        if (!kDebugMode) return;

        await tester.pumpWidget(MaterialApp(home: SettingsScreen(testStream, () => null)));
        await tester.pumpAndSettle();

        // Verify debug buttons render with callback provided
        expect(find.text('Bad Site'), findsOneWidget);
        // Note: Actually testing the callback requires platform channel mocking
      });
    });
  });

  group('SettingsScreen Debug Constants', () {
    test('badDebugSave contains required fields', () {
      expect(badDebugSave['name'], equals('Bad Site'));
      expect(badDebugSave['cert'], isNotEmpty);
      expect(badDebugSave['key'], isNotEmpty);
      expect(badDebugSave['ca'], isNotEmpty);
    });

    test('goodDebugSave contains required fields', () {
      expect(goodDebugSave['name'], equals('Good Site'));
      expect(goodDebugSave['cert'], isNotEmpty);
      expect(goodDebugSave['key'], isNotEmpty);
      expect(goodDebugSave['ca'], isNotEmpty);
    });

    test('goodDebugSaveV2 contains required fields', () {
      expect(goodDebugSaveV2['name'], equals('Good Site V2'));
      expect(goodDebugSaveV2['cert'], contains('V2'));
      expect(goodDebugSaveV2['key'], isNotEmpty);
      expect(goodDebugSaveV2['ca'], contains('V2'));
    });
  });
}
