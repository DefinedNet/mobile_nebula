import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/errors/parse_error.dart';
import 'package:mobile_nebula/models/unsafe_route.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('UnsafeRoute.fromYaml', () {
    test('single gateway (legacy string via)', () {
      var yaml = loadYaml('''
      route: 10.0.0.0/24
      via: 100.100.1.1
      ''');
      var unsafeRoute = UnsafeRoute.fromYaml(yaml);
      expect(unsafeRoute.route, '10.0.0.0/24');
      expect(unsafeRoute.via.length, 1);
      expect(unsafeRoute.via.first.gateway, '100.100.1.1');
      expect(unsafeRoute.via.first.weight, 1);
    });

    test('single gateway IPv6 via', () {
      var yaml = loadYaml('''
      route: 3fff::1/24
      via: 100.100.1.1
      ''');
      var unsafeRoute = UnsafeRoute.fromYaml(yaml);
      expect(unsafeRoute.route, '3fff::1/24');
      expect(unsafeRoute.via.first.gateway, '100.100.1.1');
    });

    test('single gateway IPv4 route IPv6 via', () {
      var yaml = loadYaml('''
      route: 100.100.1.1/24
      via: 3fff::1
      ''');
      var unsafeRoute = UnsafeRoute.fromYaml(yaml);
      expect(unsafeRoute.route, '100.100.1.1/24');
      expect(unsafeRoute.via.first.gateway, '3fff::1');
    });

    test('single gateway IPv6 both', () {
      var yaml = loadYaml('''
      route: 2001:0DB8::1/24
      via: 3fff::1
      ''');
      var unsafeRoute = UnsafeRoute.fromYaml(yaml);
      expect(unsafeRoute.route, '2001:0DB8::1/24');
      expect(unsafeRoute.via.first.gateway, '3fff::1');
    });

    test('multi-gateway list with weights', () {
      var yaml = loadYaml('''
      route: 192.168.87.0/24
      via:
        - gateway: 10.0.0.1
          weight: 10
        - gateway: 10.0.0.2
          weight: 5
      ''');
      var unsafeRoute = UnsafeRoute.fromYaml(yaml);
      expect(unsafeRoute.route, '192.168.87.0/24');
      expect(unsafeRoute.via.length, 2);
      expect(unsafeRoute.via[0].gateway, '10.0.0.1');
      expect(unsafeRoute.via[0].weight, 10);
      expect(unsafeRoute.via[1].gateway, '10.0.0.2');
      expect(unsafeRoute.via[1].weight, 5);
    });

    test('multi-gateway list without weight defaults to 1', () {
      var yaml = loadYaml('''
      route: 10.0.0.0/24
      via:
        - gateway: 10.1.0.1
        - gateway: 10.1.0.2
      ''');
      var unsafeRoute = UnsafeRoute.fromYaml(yaml);
      expect(unsafeRoute.via.length, 2);
      expect(unsafeRoute.via[0].weight, 1);
      expect(unsafeRoute.via[1].weight, 1);
    });

    test('missing route', () {
      var yaml = loadYaml('''
      random: nope
      ''');
      expect(
        () => UnsafeRoute.fromYaml(yaml),
        throwsA(predicate((e) => e is ParseError && e.message == 'route was not a string')),
      );
    });

    test('route is not a string', () {
      var yaml = loadYaml('''
      route: 123
      ''');
      expect(
        () => UnsafeRoute.fromYaml(yaml),
        throwsA(predicate((e) => e is ParseError && e.message == 'route was not a string')),
      );
    });

    test('invalid CIDR route', () {
      var yaml = loadYaml('''
      route: nope
      ''');
      expect(
        () => UnsafeRoute.fromYaml(yaml),
        throwsA(
          predicate((e) => e is ParseError && e.message == 'unable to parse CIDR from route: missing / separator'),
        ),
      );
    });

    test('missing via', () {
      var yaml = loadYaml('''
      route: 10.1.1.1/24
      ''');
      expect(
        () => UnsafeRoute.fromYaml(yaml),
        throwsA(predicate((e) => e is ParseError && e.message == 'via was not a string')),
      );
    });

    test('via is a number (not string)', () {
      var yaml = loadYaml('''
      route: 10.1.1.1/24
      via: 123
      ''');
      expect(
        () => UnsafeRoute.fromYaml(yaml),
        throwsA(predicate((e) => e is ParseError && e.message == 'via was not a string')),
      );
    });

    test('via is an invalid ip address', () {
      var yaml = loadYaml('''
      route: 10.1.1.1/24
      via: bad
      ''');
      expect(
        () => UnsafeRoute.fromYaml(yaml),
        throwsA(predicate((e) => e is ParseError && e.message == 'via was not a valid ip address')),
      );
    });

    test('gateway list item is not a map', () {
      var yaml = loadYaml('''
      route: 10.1.1.1/24
      via:
        - 10.0.0.1
      ''');
      expect(
        () => UnsafeRoute.fromYaml(yaml),
        throwsA(predicate((e) => e is ParseError && e.message == 'via list item was not a map')),
      );
    });

    test('gateway list item missing gateway key', () {
      var yaml = loadYaml('''
      route: 10.1.1.1/24
      via:
        - weight: 5
      ''');
      expect(
        () => UnsafeRoute.fromYaml(yaml),
        throwsA(predicate((e) => e is ParseError && e.message == 'gateway was not a string')),
      );
    });

    test('gateway list item has invalid ip', () {
      var yaml = loadYaml('''
      route: 10.1.1.1/24
      via:
        - gateway: notanip
          weight: 1
      ''');
      expect(
        () => UnsafeRoute.fromYaml(yaml),
        throwsA(predicate((e) => e is ParseError && e.message == 'gateway was not a valid ip address')),
      );
    });

    test('empty via list', () {
      var yaml = loadYaml('''
      route: 10.1.1.1/24
      via: []
      ''');
      expect(
        () => UnsafeRoute.fromYaml(yaml),
        throwsA(predicate((e) => e is ParseError && e.message == 'via list was empty')),
      );
    });
  });

  group('UnsafeRoute.fromJson', () {
    test('legacy string via is migrated to single-gateway list', () {
      final route = UnsafeRoute.fromJson({'route': '10.0.0.0/24', 'via': '10.0.0.1'});
      expect(route.via.length, 1);
      expect(route.via.first.gateway, '10.0.0.1');
      expect(route.via.first.weight, 1);
    });

    test('new list via is parsed correctly', () {
      final route = UnsafeRoute.fromJson({
        'route': '10.0.0.0/24',
        'via': [
          {'gateway': '10.0.0.1', 'weight': 10},
          {'gateway': '10.0.0.2', 'weight': 5},
        ],
      });
      expect(route.via.length, 2);
      expect(route.via[0].gateway, '10.0.0.1');
      expect(route.via[0].weight, 10);
      expect(route.via[1].gateway, '10.0.0.2');
      expect(route.via[1].weight, 5);
    });

    test('null via becomes empty list', () {
      final route = UnsafeRoute.fromJson({'route': '10.0.0.0/24'});
      expect(route.via, isEmpty);
    });
  });

  group('UnsafeRoute.toJson round-trip', () {
    test('multi-gateway toJson produces list format', () {
      final route = UnsafeRoute(
        route: '192.168.87.0/24',
        via: [
          Gateway(gateway: '10.0.0.1', weight: 10),
          Gateway(gateway: '10.0.0.2', weight: 5),
        ],
      );
      final json = route.toJson();
      expect(json['route'], '192.168.87.0/24');
      expect(json['via'], isA<List>());
      final viaList = json['via'] as List;
      expect(viaList.length, 2);
      expect(viaList[0], {'gateway': '10.0.0.1', 'weight': 10});
      expect(viaList[1], {'gateway': '10.0.0.2', 'weight': 5});
    });

    test('toJson -> fromJson round-trip preserves data', () {
      final original = UnsafeRoute(
        route: '10.0.0.0/24',
        via: [
          Gateway(gateway: '10.1.0.1', weight: 3),
          Gateway(gateway: '10.1.0.2', weight: 7),
        ],
      );
      final restored = UnsafeRoute.fromJson(original.toJson());
      expect(restored.route, original.route);
      expect(restored.via.length, 2);
      expect(restored.via[0].gateway, '10.1.0.1');
      expect(restored.via[0].weight, 3);
      expect(restored.via[1].gateway, '10.1.0.2');
      expect(restored.via[1].weight, 7);
    });
  });
}
