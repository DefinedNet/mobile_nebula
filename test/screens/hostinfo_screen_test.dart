import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/screens/hostinfo_screen.dart';
import 'package:yaml/yaml.dart';

HostInfo _host({UDPAddress? currentRemote, List<UDPAddress> remotes = const [], List<String> relays = const []}) =>
    HostInfo(
      vpnAddrs: ['10.88.88.2'],
      localIndex: 1,
      remoteIndex: 2,
      // growable, the screen sorts this in place
      remoteAddresses: List.of(remotes),
      messageCounter: 0,
      currentRemote: currentRemote,
      currentRelaysToMe: relays,
    );

void main() {
  Future<void> pumpHostInfo(WidgetTester tester, HostInfo hostInfo) async {
    final site = await Site.fromYaml(loadYaml('{}'));
    await tester.pumpWidget(
      MaterialApp(
        home: HostInfoScreen(
          hostInfo: hostInfo,
          isLighthouse: false,
          pending: false,
          site: site,
          supportsQRScanning: false,
        ),
      ),
    );
    await tester.pump();
  }

  group('HostInfoScreen relay section', () {
    testWidgets('relayed tunnel shows a RELAY section above REMOTES', (tester) async {
      await pumpHostInfo(tester, _host(relays: ['10.88.88.1']));

      expect(find.text('RELAY'), findsOneWidget);
      expect(find.text('10.88.88.1'), findsOneWidget);

      final relayY = tester.getTopLeft(find.text('RELAY')).dy;
      final remotesY = tester.getTopLeft(find.text('REMOTES')).dy;
      expect(relayY, lessThan(remotesY));
    });

    testWidgets('direct tunnel has no RELAY section', (tester) async {
      await pumpHostInfo(
        tester,
        _host(
          currentRemote: UDPAddress(ip: '1.1.1.1', port: 4242),
          remotes: [UDPAddress(ip: '1.1.1.1', port: 4242)],
        ),
      );

      expect(find.text('RELAY'), findsNothing);
    });

    testWidgets('relays present but a direct remote exists is not called relayed', (tester) async {
      await pumpHostInfo(
        tester,
        _host(
          currentRemote: UDPAddress(ip: '1.1.1.1', port: 4242),
          remotes: [UDPAddress(ip: '1.1.1.1', port: 4242)],
          relays: ['10.88.88.1'],
        ),
      );

      expect(find.text('RELAY'), findsNothing);
    });

    testWidgets('multiple relays are each listed', (tester) async {
      await pumpHostInfo(tester, _host(relays: ['10.88.88.1', '10.88.88.3']));

      expect(find.text('10.88.88.1'), findsOneWidget);
      expect(find.text('10.88.88.3'), findsOneWidget);
    });
  });
}
