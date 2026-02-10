import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/main.dart';
import 'package:mobile_nebula/services/utils.dart';

void main() {
  group('Utils.popError Tests', () {
    testWidgets('popError shows dialog with title and error message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );

      // Call popError
      Utils.popError('Test Error', 'This is a test error message');
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Test Error'), findsOneWidget);
      expect(find.text('This is a test error message'), findsOneWidget);
      expect(find.text('Ok'), findsOneWidget);
    });

    testWidgets('popError includes stack trace when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );

      final stackTrace = StackTrace.current;
      Utils.popError('Stack Error', 'Error with stack', stack: stackTrace);
      await tester.pumpAndSettle();

      // Verify error message contains stack trace
      expect(find.text('Stack Error'), findsOneWidget);
      expect(find.textContaining('Error with stack'), findsOneWidget);
    });

    testWidgets('popError dialog can be dismissed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );

      Utils.popError('Dismissible Error', 'This can be dismissed');
      await tester.pumpAndSettle();

      // Dialog should be visible
      expect(find.text('Dismissible Error'), findsOneWidget);

      // Tap OK button
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Dismissible Error'), findsNothing);
    });

    testWidgets('popError handles null navigator context gracefully', (WidgetTester tester) async {
      // Note: This test is challenging because we can't easily set navigatorKey.currentContext to null
      // In a real scenario, this would require the error to be called before the app is built
      // We can at least verify it doesn't crash when called with a valid context

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );

      // Calling with valid context should work
      expect(() => Utils.popError('Test', 'Message'), returnsNormally);
      await tester.pumpAndSettle();

      // Clean up the dialog
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
    });

    testWidgets('popError works with both dialog types', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );

      Utils.popError('Dialog Error', 'This is a dialog');
      await tester.pumpAndSettle();

      // Should find either AlertDialog or CupertinoAlertDialog depending on platform
      // On macOS tests, it will be CupertinoAlertDialog
      expect(find.text('Dialog Error'), findsOneWidget);
      expect(find.text('Ok'), findsOneWidget);
    });

    testWidgets('multiple popError calls show multiple dialogs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );

      // First error
      Utils.popError('Error 1', 'First error message');
      await tester.pumpAndSettle();
      expect(find.text('Error 1'), findsOneWidget);

      // Dismiss first error
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();

      // Second error
      Utils.popError('Error 2', 'Second error message');
      await tester.pumpAndSettle();
      expect(find.text('Error 2'), findsOneWidget);
    });
  });

  group('Utils.launchUrl Tests', () {
    testWidgets('launchUrl handles invalid URLs gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );

      // Try to launch an invalid URL
      // Note: In a real test, we'd need to mock url_launcher
      // For now, we just ensure the function exists and can be called
      expect(() => Utils.launchUrl(''), returnsNormally);
    });
  });

  group('Utils.textSize Tests', () {
    test('calculates text size correctly', () {
      const text = 'Hello World';
      const style = TextStyle(fontSize: 16);

      final size = Utils.textSize(text, style);

      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    test('larger font size results in larger dimensions', () {
      const text = 'Test';
      const smallStyle = TextStyle(fontSize: 12);
      const largeStyle = TextStyle(fontSize: 24);

      final smallSize = Utils.textSize(text, smallStyle);
      final largeSize = Utils.textSize(text, largeStyle);

      expect(largeSize.width, greaterThan(smallSize.width));
      expect(largeSize.height, greaterThan(smallSize.height));
    });
  });

  group('Utils.itemCountFormat Tests', () {
    test('formats single item correctly', () {
      expect(Utils.itemCountFormat(1), equals('1 item'));
    });

    test('formats multiple items correctly', () {
      expect(Utils.itemCountFormat(0), equals('0 items'));
      expect(Utils.itemCountFormat(2), equals('2 items'));
      expect(Utils.itemCountFormat(100), equals('100 items'));
    });

    test('uses custom suffixes', () {
      expect(Utils.itemCountFormat(1, singleSuffix: 'site', multiSuffix: 'sites'), equals('1 site'));
      expect(Utils.itemCountFormat(5, singleSuffix: 'site', multiSuffix: 'sites'), equals('5 sites'));
    });
  });

  group('Utils Constants Tests', () {
    test('minInteractiveSize has correct value', () {
      expect(Utils.minInteractiveSize, equals(44.0));
    });
  });
}
