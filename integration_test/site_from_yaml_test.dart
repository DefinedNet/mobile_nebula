import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:yaml/yaml.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Site.fromYaml', () {
    testWidgets('empty config', (tester) async {
      final site = await Site.fromYaml(loadYaml('{}'));
      expect(site.lhDuration, 0);
      expect(site.staticHostmap, isEmpty);
      expect(site.unsafeRoutes, isEmpty);
      expect(site.cipher, 'aes');
      expect(site.mtu, 1300);
      expect(site.port, 0);
      expect(site.logVerbosity, 'info');
      expect(site.inboundRules, isEmpty);
      expect(site.outboundRules, isEmpty);
      expect(site.errors, isEmpty);
    });

    testWidgets('parses firewall inbound rules', (tester) async {
      final site = await Site.fromYaml(
        loadYaml('''
firewall:
  inbound:
    - port: any
      proto: any
      host: any
    - port: 443
      proto: tcp
      host: any
'''),
      );
      expect(site.errors, isEmpty);
      expect(site.inboundRules.length, 2);
      expect(site.inboundRules[0].protocol, 'any');
      expect(site.inboundRules[0].startPort, 0);
      expect(site.inboundRules[0].endPort, 0);
      expect(site.inboundRules[0].host, 'any');
      expect(site.inboundRules[1].protocol, 'tcp');
      expect(site.inboundRules[1].startPort, 443);
      expect(site.inboundRules[1].endPort, 443);
      expect(site.inboundRules[1].host, 'any');
    });

    testWidgets('parses firewall outbound rules', (tester) async {
      final site = await Site.fromYaml(
        loadYaml('''
firewall:
  outbound:
    - port: any
      proto: any
      host: any
'''),
      );
      expect(site.errors, isEmpty);
      expect(site.outboundRules.length, 1);
      expect(site.outboundRules[0].protocol, 'any');
      expect(site.outboundRules[0].startPort, 0);
      expect(site.outboundRules[0].endPort, 0);
      expect(site.outboundRules[0].host, 'any');
    });

    testWidgets('parses port range', (tester) async {
      final site = await Site.fromYaml(
        loadYaml('''
firewall:
  inbound:
    - port: 80-443
      proto: tcp
      host: any
'''),
      );
      expect(site.errors, isEmpty);
      expect(site.inboundRules.length, 1);
      expect(site.inboundRules[0].startPort, 80);
      expect(site.inboundRules[0].endPort, 443);
      expect(site.inboundRules[0].protocol, 'tcp');
    });

    testWidgets('parses groups', (tester) async {
      final site = await Site.fromYaml(
        loadYaml('''
firewall:
  inbound:
    - port: any
      proto: any
      groups:
        - eng
        - ops
'''),
      );
      expect(site.errors, isEmpty);
      expect(site.inboundRules.length, 1);
      expect(site.inboundRules[0].groups, ['eng', 'ops']);
    });

    testWidgets('parses single group', (tester) async {
      final site = await Site.fromYaml(
        loadYaml('''
firewall:
  inbound:
    - port: any
      proto: any
      group: eng
'''),
      );
      expect(site.errors, isEmpty);
      expect(site.inboundRules.length, 1);
      expect(site.inboundRules[0].groups, ['eng']);
    });

    testWidgets('parses cidr and local_cidr', (tester) async {
      final site = await Site.fromYaml(
        loadYaml('''
firewall:
  inbound:
    - port: any
      proto: any
      host: any
      cidr: 10.0.0.0/8
      local_cidr: 192.168.0.0/16
'''),
      );
      expect(site.errors, isEmpty);
      expect(site.inboundRules.length, 1);
      expect(site.inboundRules[0].remoteCidr?.toString(), '10.0.0.0/8');
      expect(site.inboundRules[0].localCidr?.toString(), '192.168.0.0/16');
    });

    testWidgets('parses ca_name and ca_sha', (tester) async {
      final site = await Site.fromYaml(
        loadYaml('''
firewall:
  inbound:
    - port: any
      proto: any
      host: any
      ca_name: my-ca
      ca_sha: deadbeef
'''),
      );
      expect(site.errors, isEmpty);
      expect(site.inboundRules.length, 1);
      expect(site.inboundRules[0].caName, 'my-ca');
      expect(site.inboundRules[0].caSha, 'deadbeef');
    });

    testWidgets('parses full config with firewall', (tester) async {
      final site = await Site.fromYaml(
        loadYaml('''
lighthouse:
  interval: 60
  hosts:
    - 1.1.1.1
static_host_map:
  '1.1.1.1':
    - 10.1.1.1:8444
  '2.2.2.2':
    - 10.2.2.2:8444
unsafe_routes:
  - route: 10.0.0.0/24
    via: 192.168.1.1
firewall:
  inbound:
    - port: 443
      proto: tcp
      host: any
  outbound:
    - port: any
      proto: any
      host: any
pki:
  key: "my-key"
cipher: chachapoly
tun:
  mtu: 1400
listen:
  port: 4242
logging:
  level: debug
'''),
      );
      expect(site.lhDuration, 60);
      expect(site.staticHostmap.length, 2);
      expect(site.staticHostmap['1.1.1.1']!.lighthouse, true);
      expect(site.staticHostmap['2.2.2.2']!.lighthouse, false);
      expect(site.unsafeRoutes.length, 1);
      expect(site.inboundRules.length, 1);
      expect(site.inboundRules[0].startPort, 443);
      expect(site.inboundRules[0].protocol, 'tcp');
      expect(site.outboundRules.length, 1);
      expect(site.outboundRules[0].startPort, 0);
      expect(site.outboundRules[0].protocol, 'any');
      expect(site.key, 'my-key');
      expect(site.cipher, 'chachapoly');
      expect(site.mtu, 1400);
      expect(site.port, 4242);
      expect(site.logVerbosity, 'debug');
      expect(site.errors, isEmpty);
    });

    testWidgets('no firewall section leaves rules empty', (tester) async {
      final site = await Site.fromYaml(
        loadYaml('''
cipher: aes
listen:
  port: 4242
'''),
      );
      expect(site.inboundRules, isEmpty);
      expect(site.outboundRules, isEmpty);
      expect(site.errors, isEmpty);
    });

    testWidgets('handles both inbound and outbound with multiple rules', (tester) async {
      final site = await Site.fromYaml(
        loadYaml('''
firewall:
  inbound:
    - port: 22
      proto: tcp
      host: any
    - port: 443
      proto: tcp
      groups:
        - web
    - port: any
      proto: icmp
      host: any
  outbound:
    - port: any
      proto: any
      host: any
    - port: 53
      proto: udp
      host: any
'''),
      );
      expect(site.errors, isEmpty);
      expect(site.inboundRules.length, 3);
      expect(site.inboundRules[0].startPort, 22);
      expect(site.inboundRules[0].protocol, 'tcp');
      expect(site.inboundRules[1].startPort, 443);
      expect(site.inboundRules[1].groups, ['web']);
      expect(site.inboundRules[2].protocol, 'icmp');

      expect(site.outboundRules.length, 2);
      expect(site.outboundRules[0].protocol, 'any');
      expect(site.outboundRules[1].startPort, 53);
      expect(site.outboundRules[1].protocol, 'udp');
    });
  });
}
