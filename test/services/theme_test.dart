import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/services/theme.dart';
import 'package:mobile_nebula/services/utils.dart';

void main() {
  group('MaterialTheme Tests', () {
    late MaterialTheme theme;

    setUp(() {
      final textTheme = Typography.material2021().black;
      theme = MaterialTheme(textTheme);
    });

    group('Light Theme', () {
      test('creates light theme', () {
        final lightTheme = theme.light();

        expect(lightTheme, isNotNull);
        expect(lightTheme.brightness, equals(Brightness.light));
        expect(lightTheme.useMaterial3, isTrue);
      });

      test('light theme has badge theme configured', () {
        final lightTheme = theme.light();

        expect(lightTheme.badgeTheme, isNotNull);
        expect(lightTheme.badgeTheme.backgroundColor, isNotNull);
        expect(lightTheme.badgeTheme.textColor, isNotNull);
        expect(lightTheme.badgeTheme.textStyle, isNotNull);
      });

      test('light theme badge has correct text style', () {
        final lightTheme = theme.light();
        final badgeTextStyle = lightTheme.badgeTheme.textStyle;

        expect(badgeTextStyle?.fontWeight, equals(FontWeight.w500));
        expect(badgeTextStyle?.fontSize, equals(12));
      });

      test('light theme has custom primary container color', () {
        final lightTheme = theme.light();

        // Verify custom primaryContainer color (white)
        expect(
          lightTheme.colorScheme.primaryContainer,
          equals(const Color.fromRGBO(255, 255, 255, 1)),
        );
      });

      test('light theme has custom secondary container color', () {
        final lightTheme = theme.light();

        // Verify custom onSecondaryContainer color
        expect(
          lightTheme.colorScheme.onSecondaryContainer,
          equals(const Color.fromRGBO(138, 151, 168, 1)),
        );
      });

      test('light theme has custom surface color', () {
        final lightTheme = theme.light();

        // Verify custom surface color
        expect(
          lightTheme.colorScheme.surface,
          equals(const Color.fromARGB(255, 226, 229, 233)),
        );
      });
    });

    group('Dark Theme', () {
      test('creates dark theme', () {
        final darkTheme = theme.dark();

        expect(darkTheme, isNotNull);
        expect(darkTheme.brightness, equals(Brightness.dark));
        expect(darkTheme.useMaterial3, isTrue);
      });

      test('dark theme has badge theme configured', () {
        final darkTheme = theme.dark();

        expect(darkTheme.badgeTheme, isNotNull);
        expect(darkTheme.badgeTheme.backgroundColor, isNotNull);
        expect(darkTheme.badgeTheme.textColor, isNotNull);
        expect(darkTheme.badgeTheme.textStyle, isNotNull);
      });

      test('dark theme badge uses different colors than light', () {
        final lightTheme = theme.light();
        final darkTheme = theme.dark();

        expect(
          lightTheme.badgeTheme.backgroundColor,
          isNot(equals(darkTheme.badgeTheme.backgroundColor)),
        );
      });

      test('dark theme has custom primary container color', () {
        final darkTheme = theme.dark();

        // Verify custom primaryContainer color for dark mode
        expect(
          darkTheme.colorScheme.primaryContainer,
          equals(const Color.fromRGBO(43, 50, 59, 1)),
        );
      });

      test('dark theme has custom surface color', () {
        final darkTheme = theme.dark();

        // Verify custom surface color for dark mode
        expect(
          darkTheme.colorScheme.surface,
          equals(const Color.fromARGB(255, 22, 25, 29)),
        );
      });

      test('dark theme badge has purple background', () {
        final darkTheme = theme.dark();

        expect(
          darkTheme.badgeTheme.backgroundColor,
          equals(const Color.fromARGB(255, 93, 34, 221)),
        );
      });

      test('dark theme badge has light text color', () {
        final darkTheme = theme.dark();

        expect(
          darkTheme.badgeTheme.textColor,
          equals(const Color.fromARGB(255, 223, 211, 248)),
        );
      });
    });

    group('Medium Contrast Themes', () {
      test('creates light medium contrast theme', () {
        final lightMedium = theme.lightMediumContrast();

        expect(lightMedium, isNotNull);
        expect(lightMedium.brightness, equals(Brightness.light));
      });

      test('creates dark medium contrast theme', () {
        final darkMedium = theme.darkMediumContrast();

        expect(darkMedium, isNotNull);
        expect(darkMedium.brightness, equals(Brightness.dark));
      });
    });

    group('High Contrast Themes', () {
      test('creates light high contrast theme', () {
        final lightHigh = theme.lightHighContrast();

        expect(lightHigh, isNotNull);
        expect(lightHigh.brightness, equals(Brightness.light));
      });

      test('creates dark high contrast theme', () {
        final darkHigh = theme.darkHighContrast();

        expect(darkHigh, isNotNull);
        expect(darkHigh.brightness, equals(Brightness.dark));
      });
    });

    group('Color Schemes', () {
      test('light scheme has expected colors', () {
        final scheme = MaterialTheme.lightScheme();

        expect(scheme.brightness, equals(Brightness.light));
        expect(scheme.primary, isNotNull);
        expect(scheme.onPrimary, isNotNull);
        expect(scheme.secondary, isNotNull);
        expect(scheme.error, isNotNull);
      });

      test('dark scheme has expected colors', () {
        final scheme = MaterialTheme.darkScheme();

        expect(scheme.brightness, equals(Brightness.dark));
        expect(scheme.primary, isNotNull);
        expect(scheme.onPrimary, isNotNull);
        expect(scheme.secondary, isNotNull);
        expect(scheme.error, isNotNull);
      });

      test('light and dark schemes have different colors', () {
        final light = MaterialTheme.lightScheme();
        final dark = MaterialTheme.darkScheme();

        expect(light.primary, isNot(equals(dark.primary)));
        expect(light.surface, isNot(equals(dark.surface)));
      });
    });

    group('Text Theme Integration', () {
      test('theme applies text theme correctly', () {
        final lightTheme = theme.light();

        expect(lightTheme.textTheme, isNotNull);
        expect(lightTheme.textTheme.bodyLarge, isNotNull);
        expect(lightTheme.textTheme.bodyMedium, isNotNull);
        expect(lightTheme.textTheme.bodySmall, isNotNull);
      });
    });

    group('Badge Theme Consistency', () {
      test('all theme variants have badge theme', () {
        expect(theme.light().badgeTheme, isNotNull);
        expect(theme.dark().badgeTheme, isNotNull);
        expect(theme.lightMediumContrast().badgeTheme, isNotNull);
        expect(theme.darkMediumContrast().badgeTheme, isNotNull);
        expect(theme.lightHighContrast().badgeTheme, isNotNull);
        expect(theme.darkHighContrast().badgeTheme, isNotNull);
      });

      test('all badge themes have consistent text style properties', () {
        final themes = [
          theme.light(),
          theme.dark(),
          theme.lightMediumContrast(),
          theme.darkMediumContrast(),
          theme.lightHighContrast(),
          theme.darkHighContrast(),
        ];

        for (final t in themes) {
          final textStyle = t.badgeTheme.textStyle;
          expect(textStyle?.fontWeight, equals(FontWeight.w500));
          expect(textStyle?.fontSize, equals(12));
        }
      });
    });
  });

  group('Utils.createTextTheme Integration', () {
    testWidgets('creates text theme with Inter font', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final textTheme = Utils.createTextTheme(context, "Inter", "Inter");
              expect(textTheme, isNotNull);
              expect(textTheme.bodyLarge, isNotNull);
              expect(textTheme.bodyMedium, isNotNull);
              expect(textTheme.displayLarge, isNotNull);
              return Container();
            },
          ),
        ),
      );
    });
  });
}
