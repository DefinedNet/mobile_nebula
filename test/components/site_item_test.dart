import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/components/site_item.dart';

import '../test_helpers.dart';

/// Helper to find text within RichText widgets
Finder findRichText(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is! RichText) return false;

    String extractText(InlineSpan span) {
      if (span is TextSpan) {
        final buffer = StringBuffer();
        if (span.text != null) buffer.write(span.text);
        span.children?.forEach((child) {
          buffer.write(extractText(child));
        });
        return buffer.toString();
      }
      return '';
    }

    return extractText(widget.text).contains(text);
  });
}

void main() {
  group('SiteItem Widget Tests', () {
    testWidgets('displays site name correctly', (WidgetTester tester) async {
      final site = createMockSite(name: 'Test Site');

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      expect(findRichText('Test Site'), findsOneWidget);
    });

    testWidgets('displays managed badge for managed sites', (WidgetTester tester) async {
      final site = createMockSite(name: 'Test Managed Site', managed: true);

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      expect(findRichText('Test Managed Site'), findsOneWidget);
      expect(find.text('Managed'), findsOneWidget);
    });

    testWidgets('does not display managed badge for unmanaged sites', (WidgetTester tester) async {
      final site = createMockSite(name: 'Test Unmanaged Site', managed: false);

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      expect(findRichText('Test Unmanaged Site'), findsOneWidget);
      expect(find.text('Managed'), findsNothing);
    });

    testWidgets('displays site status when connected', (WidgetTester tester) async {
      final site = createMockSite(name: 'Test Connected Site', connected: true, status: 'Connected');

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      expect(findRichText('Test Connected Site'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('displays "Resolve errors" when site has errors', (WidgetTester tester) async {
      final site = createMockSite(name: 'Error Site', errors: ['Certificate expired']);

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      expect(find.text('Resolve errors'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    testWidgets('switch reflects connection state', (WidgetTester tester) async {
      final site = createMockSite(connected: true);

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('switch is disabled when site has errors and is disconnected', (WidgetTester tester) async {
      final site = createMockSite(connected: false, errors: ['Some error']);

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      final switchFinder = find.byType(Switch);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.onChanged, isNull);
    });

    testWidgets('switch is enabled when site has errors but is connected', (WidgetTester tester) async {
      final site = createMockSite(connected: true, errors: ['Some error']);

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      final switchFinder = find.byType(Switch);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.onChanged, isNotNull);
    });

    testWidgets('switch is enabled when site has no errors', (WidgetTester tester) async {
      final site = createMockSite(connected: false, errors: []);

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      final switchFinder = find.byType(Switch);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.onChanged, isNotNull);
    });

    testWidgets('displays Details button', (WidgetTester tester) async {
      final site = createMockSite(name: 'Test Site');

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('calls onPressed when Details is tapped', (WidgetTester tester) async {
      final site = createMockSite(name: 'Test Site');
      bool wasPressed = false;

      await tester.pumpWidget(
        createTestApp(
          child: SiteItem(site: site, onPressed: () => wasPressed = true),
        ),
      );

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(wasPressed, isTrue);
    });

    testWidgets('badge uses theme colors', (WidgetTester tester) async {
      final site = createMockSite(name: 'Managed Site', managed: true);

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      // Verify badge is rendered
      expect(find.text('Managed'), findsOneWidget);

      // Find the Container with badge decoration
      final badgeContainer = tester.widget<Container>(
        find.ancestor(of: find.text('Managed'), matching: find.byType(Container)).first,
      );

      expect(badgeContainer.decoration, isA<BoxDecoration>());
      final decoration = badgeContainer.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('status text uses correct styling', (WidgetTester tester) async {
      final site = createMockSite(status: 'Disconnected');

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      final statusText = tester.widget<Text>(find.text('Disconnected'));
      expect(statusText.style?.fontSize, equals(14));
      expect(statusText.style?.fontWeight, equals(FontWeight.w500));
    });

    testWidgets('site name uses correct styling', (WidgetTester tester) async {
      final site = createMockSite(name: 'Styled Site');

      await tester.pumpWidget(createTestApp(child: SiteItem(site: site)));

      // Find the RichText widget that contains the site name
      final richTextFinder = findRichText('Styled Site');
      expect(richTextFinder, findsOneWidget);

      final richText = tester.widget<RichText>(richTextFinder);
      final textSpan = richText.text as TextSpan;

      // Recursively find TextSpan with the site name
      TextSpan? findTextSpan(InlineSpan span, String text) {
        if (span is TextSpan) {
          if (span.text == text) return span;
          if (span.children != null) {
            for (var child in span.children!) {
              final found = findTextSpan(child, text);
              if (found != null) return found;
            }
          }
        }
        return null;
      }

      final siteNameSpan = findTextSpan(textSpan, 'Styled Site');
      expect(siteNameSpan, isNotNull);
      expect(siteNameSpan!.style?.fontSize, equals(16));
      expect(siteNameSpan.style?.fontWeight, equals(FontWeight.w500));
    });
  });
}
