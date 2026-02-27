import 'package:mobile_nebula/models/site.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Site.fromYaml', () {
    test('empty config', () async {
      final site = await Site.fromYaml(loadYaml('{}'));
      expect(site.lhDuration, 0);
      expect(site.staticHostmap, isEmpty);
      expect(site.unsafeRoutes, isEmpty);
      expect(site.cipher, 'aes');
      expect(site.mtu, 1300);
      expect(site.port, 0);
      expect(site.logVerbosity, 'info');
      expect(site.errors, isEmpty);
    });

    group('lighthouse', () {
      test('parses interval', () async {
        final site = await Site.fromYaml(
          loadYaml('''
lighthouse:
  interval: 120
'''),
        );
        expect(site.lhDuration, 120);
        expect(site.errors, isEmpty);
      });

      test('parses string interval', () async {
        final site = await Site.fromYaml(
          loadYaml('''
lighthouse:
  interval: "120"
'''),
        );
        expect(site.lhDuration, 120);
        expect(site.errors, isEmpty);
      });

      test('errors on non-numeric interval', () async {
        final site = await Site.fromYaml(
          loadYaml('''
lighthouse:
  interval: abc
'''),
        );
        expect(site.lhDuration, 0);
        expect(site.errors, contains('lighthouse.interval could not be parsed as an integer'));
      });

      test('errors on invalid lighthouse host ip', () async {
        final site = await Site.fromYaml(
          loadYaml('''
lighthouse:
  hosts:
    - 999.999.999.999
'''),
        );
        expect(site.errors, contains('lighthouse.hosts entry was not a valid ip address: 999.999.999.999'));
      });

      test('errors on non-string lighthouse host entry', () async {
        final site = await Site.fromYaml(
          loadYaml('''
lighthouse:
  hosts:
    - 123
'''),
        );
        expect(site.errors, contains('lighthouse.hosts entry was not a string: 123'));
      });
    });

    group('static_host_map', () {
      test('parses valid static hosts', () async {
        final site = await Site.fromYaml(
          loadYaml('''
static_host_map:
  '1.1.1.1':
    - 10.1.1.1:8444
  '2.2.2.2':
    - 10.2.2.2:8444
    - 10.2.2.3:8444
'''),
        );
        expect(site.staticHostmap.length, 2);
        expect(site.staticHostmap['1.1.1.1']!.destinations.length, 1);
        expect(site.staticHostmap['1.1.1.1']!.destinations[0].ip, '10.1.1.1');
        expect(site.staticHostmap['1.1.1.1']!.destinations[0].port, 8444);
        expect(site.staticHostmap['1.1.1.1']!.lighthouse, false);
        expect(site.staticHostmap['2.2.2.2']!.destinations.length, 2);
        expect(site.errors, isEmpty);
      });

      test('marks lighthouse hosts', () async {
        final site = await Site.fromYaml(
          loadYaml('''
lighthouse:
  hosts:
    - 1.1.1.1
static_host_map:
  '1.1.1.1':
    - 10.1.1.1:8444
  '2.2.2.2':
    - 10.2.2.2:8444
'''),
        );
        expect(site.staticHostmap['1.1.1.1']!.lighthouse, true);
        expect(site.staticHostmap['2.2.2.2']!.lighthouse, false);
        expect(site.errors, isEmpty);
      });

      test('errors on invalid vpn address', () async {
        final site = await Site.fromYaml(
          loadYaml('''
static_host_map:
  'not-an-ip':
    - 10.1.1.1:8444
'''),
        );
        expect(site.staticHostmap, isEmpty);
        expect(site.errors, contains('invalid vpn address in static_host_map: not-an-ip'));
      });

      test('errors on non-string destination', () async {
        final site = await Site.fromYaml(
          loadYaml('''
static_host_map:
  '1.1.1.1':
    - 123
'''),
        );
        expect(site.staticHostmap['1.1.1.1']!.destinations, isEmpty);
        expect(site.errors, contains('static_host_map destination for 1.1.1.1 was not a string: 123'));
      });

      test('errors on non-list destinations', () async {
        final site = await Site.fromYaml(
          loadYaml('''
static_host_map:
  '1.1.1.1': not-a-list
'''),
        );
        expect(site.errors, contains('static_host_map destinations for 1.1.1.1 was not a list of strings'));
      });

      test('errors on invalid host:port string', () async {
        final site = await Site.fromYaml(
          loadYaml('''
static_host_map:
  '1.1.1.1':
    - 'bad-host-port'
'''),
        );
        expect(site.staticHostmap['1.1.1.1']!.destinations, isEmpty);
        expect(site.errors, isNotEmpty);
      });
    });

    group('unsafe_routes', () {
      test('parses valid unsafe routes', () async {
        final site = await Site.fromYaml(
          loadYaml('''
unsafe_routes:
  - route: 10.0.0.0/24
    via: 192.168.1.1
'''),
        );
        expect(site.unsafeRoutes.length, 1);
        expect(site.unsafeRoutes[0].route, '10.0.0.0/24');
        expect(site.unsafeRoutes[0].via, '192.168.1.1');
        expect(site.errors, isEmpty);
      });

      test('parses multiple unsafe routes', () async {
        final site = await Site.fromYaml(
          loadYaml('''
unsafe_routes:
  - route: 10.0.0.0/24
    via: 192.168.1.1
  - route: 172.16.0.0/16
    via: 192.168.1.2
'''),
        );
        expect(site.unsafeRoutes.length, 2);
        expect(site.errors, isEmpty);
      });

      test('errors on invalid route CIDR', () async {
        final site = await Site.fromYaml(
          loadYaml('''
unsafe_routes:
  - route: not-a-cidr
    via: 192.168.1.1
'''),
        );
        expect(site.unsafeRoutes, isEmpty);
        expect(
          site.errors,
          contains('failed to parse unsafe route 1: unable to parse CIDR from route: missing / separator'),
        );
      });

      test('errors on missing via', () async {
        final site = await Site.fromYaml(
          loadYaml('''
unsafe_routes:
  - route: 10.0.0.0/24
'''),
        );
        expect(site.unsafeRoutes, isEmpty);
        expect(site.errors, contains('failed to parse unsafe route 1: via was not a string'));
      });

      test('errors on non-map entry', () async {
        final site = await Site.fromYaml(
          loadYaml('''
unsafe_routes:
  - not-a-map
'''),
        );
        expect(site.unsafeRoutes, isEmpty);
        expect(site.errors, contains('failed to parse unsafe route 1: unsafe route was not a map'));
      });
    });

    group('pki', () {
      test('parses key', () async {
        final site = await Site.fromYaml(
          loadYaml('''
pki:
  key: "test-key-data"
'''),
        );
        expect(site.key, 'test-key-data');
        expect(site.errors, isEmpty);
      });

      test('ignores non-string key', () async {
        final site = await Site.fromYaml(
          loadYaml('''
pki:
  key: 123
'''),
        );
        expect(site.key, isNull);
      });
    });

    group('cipher', () {
      test('parses aes', () async {
        final site = await Site.fromYaml(loadYaml('cipher: aes'));
        expect(site.cipher, 'aes');
        expect(site.errors, isEmpty);
      });

      test('parses chachapoly', () async {
        final site = await Site.fromYaml(loadYaml('cipher: chachapoly'));
        expect(site.cipher, 'chachapoly');
        expect(site.errors, isEmpty);
      });

      test('is case insensitive', () async {
        final site = await Site.fromYaml(loadYaml('cipher: AES'));
        expect(site.cipher, 'aes');
        expect(site.errors, isEmpty);
      });

      test('errors on invalid cipher', () async {
        final site = await Site.fromYaml(loadYaml('cipher: blowfish'));
        expect(site.cipher, 'aes');
        expect(site.errors, contains('cipher was not valid: blowfish'));
      });
    });

    group('tun', () {
      test('parses mtu', () async {
        final site = await Site.fromYaml(
          loadYaml('''
tun:
  mtu: 1400
'''),
        );
        expect(site.mtu, 1400);
        expect(site.errors, isEmpty);
      });

      test('parses string mtu', () async {
        final site = await Site.fromYaml(
          loadYaml('''
tun:
  mtu: "1400"
'''),
        );
        expect(site.mtu, 1400);
        expect(site.errors, isEmpty);
      });

      test('errors on non-numeric mtu', () async {
        final site = await Site.fromYaml(
          loadYaml('''
tun:
  mtu: abc
'''),
        );
        expect(site.mtu, 1300);
        expect(site.errors, contains('tun.mtu was not a number: abc'));
      });
    });

    group('listen', () {
      test('parses port', () async {
        final site = await Site.fromYaml(
          loadYaml('''
listen:
  port: 4242
'''),
        );
        expect(site.port, 4242);
        expect(site.errors, isEmpty);
      });

      test('parses string port', () async {
        final site = await Site.fromYaml(
          loadYaml('''
listen:
  port: "4242"
'''),
        );
        expect(site.port, 4242);
        expect(site.errors, isEmpty);
      });

      test('errors on non-numeric port', () async {
        final site = await Site.fromYaml(
          loadYaml('''
listen:
  port: abc
'''),
        );
        expect(site.port, 0);
        expect(site.errors, contains('listen.port was not a number: abc'));
      });
    });

    group('logging', () {
      test('parses all valid log levels', () async {
        for (final level in ['panic', 'fatal', 'error', 'warning', 'info', 'debug']) {
          final site = await Site.fromYaml(
            loadYaml('''
logging:
  level: $level
'''),
          );
          expect(site.logVerbosity, level, reason: 'level $level should be valid');
          expect(site.errors, isEmpty, reason: 'level $level should not produce errors');
        }
      });

      test('is case insensitive', () async {
        final site = await Site.fromYaml(
          loadYaml('''
logging:
  level: DEBUG
'''),
        );
        expect(site.logVerbosity, 'debug');
        expect(site.errors, isEmpty);
      });

      test('errors on invalid log level', () async {
        final site = await Site.fromYaml(
          loadYaml('''
logging:
  level: trace
'''),
        );
        expect(site.logVerbosity, 'info');
        expect(site.errors, contains('logging.level was not valid: trace'));
      });
    });

    test('full config parses all fields together', () async {
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
      expect(site.key, 'my-key');
      expect(site.cipher, 'chachapoly');
      expect(site.mtu, 1400);
      expect(site.port, 4242);
      expect(site.logVerbosity, 'debug');
      expect(site.errors, isEmpty);
    });

    test('accumulates multiple errors', () async {
      final site = await Site.fromYaml(
        loadYaml('''
lighthouse:
  interval: abc
  hosts:
    - not-an-ip
static_host_map:
  'bad-vpn':
    - 10.1.1.1:8444
cipher: invalid
tun:
  mtu: xyz
listen:
  port: xyz
logging:
  level: trace
'''),
      );
      expect(site.errors.length, greaterThanOrEqualTo(6));
    });
  });
}
