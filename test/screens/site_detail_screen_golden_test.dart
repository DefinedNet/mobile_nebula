import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/screens/SiteDetailScreen.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SiteDetailScreen Golden Tests', () {
    setUp(() {
      // Set up default method channel handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.mobileNebula/NebulaVpnService'),
        (MethodCall methodCall) async {
          return null;
        },
      );
    });

    testWidgets('disconnected site without errors', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;

      // Mock EventChannel for the site
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.nebula/test-site-id'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      final site = createMockSite(name: 'My VPN', connected: false, status: 'Disconnected', managed: false);

      await tester.pumpWidget(createTestApp(child: SiteDetailScreen(site: site, supportsQRScanning: true)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(SiteDetailScreen), matchesGoldenFile('goldens/site_detail_disconnected.png'));
    });

    testWidgets('connected site with tunnels', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;

      // Mock EventChannel for the site
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.nebula/test-site-id'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      final site = createMockSite(name: 'Production VPN', connected: true, status: 'Connected', managed: false);

      await tester.pumpWidget(createTestApp(child: SiteDetailScreen(site: site, supportsQRScanning: true)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(SiteDetailScreen), matchesGoldenFile('goldens/site_detail_connected.png'));
    });

    testWidgets('site with errors', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;

      // Mock EventChannel for the site
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.nebula/test-site-id'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      final site = createMockSite(
        name: 'Error Site',
        connected: false,
        status: 'Disconnected',
        errors: ['Certificate has expired', 'Unable to verify certificate chain', 'Invalid configuration format'],
      );

      await tester.pumpWidget(createTestApp(child: SiteDetailScreen(site: site, supportsQRScanning: true)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(SiteDetailScreen), matchesGoldenFile('goldens/site_detail_with_errors.png'));
    });

    testWidgets('managed site', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;

      // Mock EventChannel for the site
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.nebula/test-site-id'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      final site = createMockSite(
        name: 'Managed VPN',
        connected: true,
        status: 'Connected',
        managed: true,
        lastManagedUpdate: DateTime(2024, 1, 15, 10, 30),
      );

      await tester.pumpWidget(createTestApp(child: SiteDetailScreen(site: site, supportsQRScanning: true)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(SiteDetailScreen), matchesGoldenFile('goldens/site_detail_managed.png'));
    });

    testWidgets('site connecting state', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;

      // Mock EventChannel for the site
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.nebula/test-site-id'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      final site = createMockSite(name: 'Connecting VPN', connected: true, status: 'Connecting');

      await tester.pumpWidget(createTestApp(child: SiteDetailScreen(site: site, supportsQRScanning: true)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(SiteDetailScreen), matchesGoldenFile('goldens/site_detail_connecting.png'));
    });

    testWidgets('site with error and connected', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;

      // Mock EventChannel for the site
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.nebula/test-site-id'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      final site = createMockSite(
        name: 'Warning VPN',
        connected: true,
        status: 'Connected',
        errors: ['Certificate expiring soon'],
      );

      await tester.pumpWidget(createTestApp(child: SiteDetailScreen(site: site, supportsQRScanning: true)));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SiteDetailScreen),
        matchesGoldenFile('goldens/site_detail_connected_with_error.png'),
      );
    });

    testWidgets('long site name', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;

      // Mock EventChannel for the site
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.defined.nebula/test-site-id'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      final site = createMockSite(
        name: 'Very Long Site Name That Might Wrap Across Multiple Lines',
        connected: false,
        status: 'Disconnected',
      );

      await tester.pumpWidget(createTestApp(child: SiteDetailScreen(site: site, supportsQRScanning: false)));
      await tester.pumpAndSettle();

      await expectLater(find.byType(SiteDetailScreen), matchesGoldenFile('goldens/site_detail_long_name.png'));
    });
  });
}
