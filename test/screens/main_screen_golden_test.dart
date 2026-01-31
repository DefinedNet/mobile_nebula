import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/screens/MainScreen.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MainScreen Golden Tests', () {
    late StreamController testStream;

    setUp(() {
      testStream = StreamController.broadcast();
    });

    tearDown(() {
      testStream.close();
    });

    testWidgets('empty state - no sites', (WidgetTester tester) async {
      // Mock platform channel to return empty sites list
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.mobileNebula/NebulaVpnService'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'listSites') {
            return jsonEncode({});
          } else if (methodCall.method == 'android.deviceHasCamera') {
            return true;
          }
          return null;
        },
      );

      await tester.pumpWidget(createTestApp(child: MainScreen(testStream)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MainScreen), matchesGoldenFile('goldens/main_screen_empty.png'));
    });

    testWidgets('with multiple sites - mixed states', (WidgetTester tester) async {
      // Mock EventChannels for each site
      for (var siteId in ['site-1', 'site-2', 'site-3']) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel('net.defined.nebula/$siteId'), (
          MethodCall methodCall,
        ) async {
          return null;
        });
      }

      // Mock platform channel to return sites
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.mobileNebula/NebulaVpnService'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'listSites') {
            return jsonEncode({
              'site-1': {
                'id': 'site-1',
                'name': 'Production VPN',
                'connected': true,
                'status': 'Connected',
                'managed': true,
                'staticHostmap': {},
                'unsafeRoutes': [],
                'ca': [],
                'lhDuration': 0,
                'port': 4242,
                'mtu': 1300,
                'cipher': 'aes',
                'sortKey': 0,
                'logFile': '',
                'logVerbosity': 'info',
                'errors': [],
              },
              'site-2': {
                'id': 'site-2',
                'name': 'Development VPN',
                'connected': false,
                'status': 'Disconnected',
                'managed': false,
                'staticHostmap': {},
                'unsafeRoutes': [],
                'ca': [],
                'lhDuration': 0,
                'port': 4242,
                'mtu': 1300,
                'cipher': 'aes',
                'sortKey': 1,
                'logFile': '',
                'logVerbosity': 'info',
                'errors': [],
              },
              'site-3': {
                'id': 'site-3',
                'name': 'Staging VPN',
                'connected': false,
                'status': 'Disconnected',
                'managed': false,
                'staticHostmap': {},
                'unsafeRoutes': [],
                'ca': [],
                'lhDuration': 0,
                'port': 4242,
                'mtu': 1300,
                'cipher': 'aes',
                'sortKey': 2,
                'logFile': '',
                'logVerbosity': 'info',
                'errors': ['Certificate expired'],
              },
            });
          } else if (methodCall.method == 'android.registerActiveSite' ||
              methodCall.method == 'android.deviceHasCamera') {
            return true;
          }
          return null;
        },
      );

      await tester.pumpWidget(createTestApp(child: MainScreen(testStream)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MainScreen), matchesGoldenFile('goldens/main_screen_with_sites.png'));
    });

    testWidgets('single connected site', (WidgetTester tester) async {
      // Mock EventChannel for the site
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('net.defined.nebula/site-1'), (
        MethodCall methodCall,
      ) async {
        return null;
      });

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.mobileNebula/NebulaVpnService'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'listSites') {
            return jsonEncode({
              'site-1': {
                'id': 'site-1',
                'name': 'My VPN',
                'connected': true,
                'status': 'Connected',
                'managed': false,
                'staticHostmap': {},
                'unsafeRoutes': [],
                'ca': [],
                'lhDuration': 0,
                'port': 4242,
                'mtu': 1300,
                'cipher': 'aes',
                'sortKey': 0,
                'logFile': '',
                'logVerbosity': 'info',
                'errors': [],
              },
            });
          } else if (methodCall.method == 'android.registerActiveSite' ||
              methodCall.method == 'android.deviceHasCamera') {
            return true;
          }
          return null;
        },
      );

      await tester.pumpWidget(createTestApp(child: MainScreen(testStream)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MainScreen), matchesGoldenFile('goldens/main_screen_single_connected.png'));
    });

    testWidgets('site with errors', (WidgetTester tester) async {
      // Mock EventChannel for the site
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('net.defined.nebula/site-1'), (
        MethodCall methodCall,
      ) async {
        return null;
      });

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.mobileNebula/NebulaVpnService'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'listSites') {
            return jsonEncode({
              'site-1': {
                'id': 'site-1',
                'name': 'Error Site',
                'connected': false,
                'status': 'Disconnected',
                'managed': false,
                'staticHostmap': {},
                'unsafeRoutes': [],
                'ca': [],
                'lhDuration': 0,
                'port': 4242,
                'mtu': 1300,
                'cipher': 'aes',
                'sortKey': 0,
                'logFile': '',
                'logVerbosity': 'info',
                'errors': ['Certificate has expired', 'Invalid configuration'],
              },
            });
          } else if (methodCall.method == 'android.registerActiveSite' ||
              methodCall.method == 'android.deviceHasCamera') {
            return true;
          }
          return null;
        },
      );

      await tester.pumpWidget(createTestApp(child: MainScreen(testStream)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MainScreen), matchesGoldenFile('goldens/main_screen_with_errors.png'));
    });

    testWidgets('managed sites', (WidgetTester tester) async {
      // Mock EventChannels for each site
      for (var siteId in ['site-1', 'site-2']) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel('net.defined.nebula/$siteId'), (
          MethodCall methodCall,
        ) async {
          return null;
        });
      }

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.mobileNebula/NebulaVpnService'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'listSites') {
            return jsonEncode({
              'site-1': {
                'id': 'site-1',
                'name': 'Managed Production',
                'connected': true,
                'status': 'Connected',
                'managed': true,
                'staticHostmap': {},
                'unsafeRoutes': [],
                'ca': [],
                'lhDuration': 0,
                'port': 4242,
                'mtu': 1300,
                'cipher': 'aes',
                'sortKey': 0,
                'logFile': '',
                'logVerbosity': 'info',
                'errors': [],
              },
              'site-2': {
                'id': 'site-2',
                'name': 'Managed Staging',
                'connected': false,
                'status': 'Disconnected',
                'managed': true,
                'staticHostmap': {},
                'unsafeRoutes': [],
                'ca': [],
                'lhDuration': 0,
                'port': 4242,
                'mtu': 1300,
                'cipher': 'aes',
                'sortKey': 1,
                'logFile': '',
                'logVerbosity': 'info',
                'errors': [],
              },
            });
          } else if (methodCall.method == 'android.registerActiveSite' ||
              methodCall.method == 'android.deviceHasCamera') {
            return true;
          }
          return null;
        },
      );

      await tester.pumpWidget(createTestApp(child: MainScreen(testStream)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(MainScreen), matchesGoldenFile('goldens/main_screen_managed_sites.png'));
    });
  });
}
