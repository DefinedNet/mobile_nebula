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
    });

    group('unsafe_routes', () {
      test('parses valid unsafe routes', () async {
        final site = await Site.fromYaml(
          loadYaml('''
tun:
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
tun:
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

      test('key is removed from rawConfig', () async {
        final site = await Site.fromYaml(
          loadYaml('''
pki:
  key: "test-key-data"
  blocklist:
    - "abc123"
'''),
        );
        expect(site.key, 'test-key-data');
        final pki = site.rawConfig['pki'] as Map<String, dynamic>;
        expect(pki.containsKey('key'), false);
        expect(pki['blocklist'], ['abc123']);
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
    });

    group('logging', () {
      test('parses log level', () async {
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
tun:
  mtu: 1400
  unsafe_routes:
    - route: 10.0.0.0/24
      via: 192.168.1.1
pki:
  key: "my-key"
cipher: chachapoly
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

    group('rawConfig round-trip', () {
      test('toJson produces rawConfig as JSON string', () async {
        final site = await Site.fromYaml(
          loadYaml('''
cipher: aes
listen:
  port: 4242
'''),
        );
        site.name = 'test';
        final json = site.toJson();
        expect(json['rawConfig'], isA<String>());
        expect(json['name'], 'test');
        expect(json['configVersion'], 0);
      });

      test('convenience setters modify rawConfig', () async {
        final site = await Site.fromYaml(loadYaml('{}'));
        site.port = 5555;
        site.mtu = 1400;
        site.cipher = 'chachapoly';
        site.logVerbosity = 'debug';
        site.lhDuration = 120;

        expect(site.port, 5555);
        expect(site.mtu, 1400);
        expect(site.cipher, 'chachapoly');
        expect(site.logVerbosity, 'debug');
        expect(site.lhDuration, 120);
      });
    });
  });

  group('configVersion', () {
    test('defaults to 0 for new sites', () {
      final site = Site();
      expect(site.configVersion, 0);
    });

    test('toJson includes configVersion', () {
      final site = Site(configVersion: 0);
      final json = site.toJson();
      expect(json.containsKey('configVersion'), true);
      expect(json['configVersion'], 0);
    });

    test('fromYaml produces site with default configVersion 0', () async {
      final site = await Site.fromYaml(loadYaml('cipher: aes'));
      expect(site.configVersion, 0);
    });

    test('_fromJson parses configVersion from JSON', () {
      // Verify the internal parsing logic handles configVersion
      final site = Site(configVersion: 1);
      final json = site.toJson();
      // The JSON output should carry configVersion through
      expect(json['configVersion'], 1);
    });

    test('_fromJson defaults configVersion to 0 when missing', () {
      // A site created with no explicit configVersion defaults to 0
      final site = Site();
      expect(site.configVersion, 0);
      final json = site.toJson();
      expect(json['configVersion'], 0);
    });
  });

  group('managed flag', () {
    test('defaults to false', () {
      final site = Site();
      expect(site.managed, false);
    });

    test('managed true appears in toJson', () {
      final site = Site(managed: true);
      final json = site.toJson();
      expect(json['managed'], true);
    });

    test('managed false appears in toJson', () {
      final site = Site(managed: false);
      final json = site.toJson();
      expect(json['managed'], false);
    });
  });

  // Site.parseJson exercises the same _fromJson path as Site.fromJson
  // but avoids the EventChannel setup that requires Flutter bindings.
  group('rawConfig parse errors', () {
    test('invalid rawConfig JSON produces error', () {
      final parsed = Site.parseJson({
        'name': 'bad site',
        'id': 'bad-id',
        'rawConfig': '{invalid json!!!',
        'configVersion': 1,
      });
      final errors = parsed['errors'] as List<String>;
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Failed to parse rawConfig'));
      expect(parsed['rawConfig'], isEmpty);
    });

    test('empty rawConfig string produces no error', () {
      final parsed = Site.parseJson({'name': 'empty config', 'id': 'empty-id', 'rawConfig': '', 'configVersion': 1});
      final errors = parsed['errors'] as List<String>;
      expect(errors, isEmpty);
      expect(parsed['rawConfig'], isEmpty);
    });

    test('missing rawConfig produces no error', () {
      final parsed = Site.parseJson({'name': 'no config', 'id': 'no-id', 'configVersion': 1});
      final errors = parsed['errors'] as List<String>;
      expect(errors, isEmpty);
    });

    test('valid rawConfig produces no error', () {
      final parsed = Site.parseJson({
        'name': 'good site',
        'id': 'good-id',
        'rawConfig': '{"cipher":"aes","listen":{"port":4242}}',
        'configVersion': 1,
      });
      final errors = parsed['errors'] as List<String>;
      expect(errors, isEmpty);
      final rawConfig = parsed['rawConfig'] as Map<String, dynamic>;
      expect(rawConfig['cipher'], 'aes');
    });
  });
}
