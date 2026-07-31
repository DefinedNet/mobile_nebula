import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/models/certificate.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/screens/site_tunnels_screen.dart';
import 'package:yaml/yaml.dart';

Certificate _cert(String name) => Certificate(
  2,
  name,
  ['10.88.88.2/24'],
  [],
  [],
  false,
  DateTime.now().subtract(Duration(days: 1)),
  DateTime.now().add(Duration(days: 1)),
  'issuer',
  'pubkey',
  'CURVE25519',
  'fingerprint',
  'signature',
);

HostInfo _host(String vpnAddr, {String? certName, List<String> relays = const []}) => HostInfo(
  vpnAddrs: [vpnAddr],
  localIndex: 1,
  remoteIndex: 2,
  remoteAddresses: [],
  messageCounter: 0,
  cert: certName == null ? null : _cert(certName),
  currentRelaysToMe: relays,
);

// Longer than any real cert name, and unbroken so it cannot wrap
const longName =
    'a-very-long-hostname-that-someone-will-inevitably-use-in-production-'
    'because-naming-conventions-are-hard-and-nobody-tests-this-0123456789';

void main() {
  Future<void> pumpTunnels(WidgetTester tester, List<HostInfo> tunnels, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    final site = await Site.fromYaml(loadYaml('{}'));
    await tester.pumpWidget(
      MaterialApp(
        home: SiteTunnelsScreen(
          site: site,
          tunnels: tunnels,
          pending: false,
          onChanged: null,
          supportsQRScanning: false,
        ),
      ),
    );
    await tester.pump();
  }

  group('SiteTunnelsScreen long hostnames', () {
    testWidgets('relayed host with a long name does not overflow', (tester) async {
      await pumpTunnels(tester, [
        _host('10.88.88.2', certName: longName, relays: ['10.88.88.1']),
      ], size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      // The relay icon survives, the name is what gives way
      expect(find.byIcon(Icons.alt_route), findsOneWidget);
    });

    testWidgets('long name is ellipsized rather than clipped', (tester) async {
      await pumpTunnels(tester, [
        _host('10.88.88.2', certName: longName, relays: ['10.88.88.1']),
      ], size: const Size(320, 640));

      final text = tester.widget<Text>(find.text(longName));
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('relay icon is not pushed off screen by a long name', (tester) async {
      await pumpTunnels(tester, [
        _host('10.88.88.2', certName: longName, relays: ['10.88.88.1']),
      ], size: const Size(320, 640));

      final icon = tester.getRect(find.byIcon(Icons.alt_route));
      expect(icon.right, lessThanOrEqualTo(320));
      expect(icon.width, greaterThan(0));
    });

    testWidgets('non relayed long name still renders without the icon', (tester) async {
      await pumpTunnels(tester, [_host('10.88.88.2', certName: longName)], size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.alt_route), findsNothing);
    });

    testWidgets('falls back to the vpn address when there is no cert', (tester) async {
      await pumpTunnels(tester, [
        _host('10.88.88.2', relays: ['10.88.88.1']),
      ], size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(find.text('10.88.88.2'), findsOneWidget);
      expect(find.byIcon(Icons.alt_route), findsOneWidget);
    });
  });
}
