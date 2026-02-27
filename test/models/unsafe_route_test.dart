import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/errors/parse_error.dart';
import 'package:mobile_nebula/models/unsafe_route.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('UnsafeRoute.fromYaml', () {
    var yaml = loadYaml('''
    route: 10.0.0.0/24
    via: 100.100.1.1
    ''');
    var unsafeRoute = UnsafeRoute.fromYaml(yaml);
    expect(unsafeRoute.route, '10.0.0.0/24');
    expect(unsafeRoute.via, '100.100.1.1');

    yaml = loadYaml('''
    route: 3fff::1/24
    via: 100.100.1.1
    ''');
    unsafeRoute = UnsafeRoute.fromYaml(yaml);
    expect(unsafeRoute.route, '3fff::1/24');
    expect(unsafeRoute.via, '100.100.1.1');

    yaml = loadYaml('''
    route: 100.100.1.1/24
    via: 3fff::1
    ''');
    unsafeRoute = UnsafeRoute.fromYaml(yaml);
    expect(unsafeRoute.route, '100.100.1.1/24');
    expect(unsafeRoute.via, '3fff::1');

    yaml = loadYaml('''
    route: 2001:0DB8::1/24
    via: 3fff::1
    ''');
    unsafeRoute = UnsafeRoute.fromYaml(yaml);
    expect(unsafeRoute.route, '2001:0DB8::1/24');
    expect(unsafeRoute.via, '3fff::1');

    yaml = loadYaml('''
    random: nope
    ''');
    expect(
      () => UnsafeRoute.fromYaml(yaml),
      throwsA(predicate((e) => e is ParseError && e.message == 'route was not a string')),
    );

    yaml = loadYaml('''
    route: 123
    ''');
    expect(
      () => UnsafeRoute.fromYaml(yaml),
      throwsA(predicate((e) => e is ParseError && e.message == 'route was not a string')),
    );

    yaml = loadYaml('''
    route: nope
    ''');
    expect(
      () => UnsafeRoute.fromYaml(yaml),
      throwsA(predicate((e) => e is ParseError && e.message == 'unable to parse CIDR from route: missing / separator')),
    );

    yaml = loadYaml('''
    route: 10.1.1.1/24
    ''');
    expect(
      () => UnsafeRoute.fromYaml(yaml),
      throwsA(predicate((e) => e is ParseError && e.message == 'via was not a string')),
    );

    yaml = loadYaml('''
    route: 10.1.1.1/24
    via: 123
    ''');
    expect(
      () => UnsafeRoute.fromYaml(yaml),
      throwsA(predicate((e) => e is ParseError && e.message == 'via was not a string')),
    );

    yaml = loadYaml('''
    route: 10.1.1.1/24
    via: bad
    ''');
    expect(
      () => UnsafeRoute.fromYaml(yaml),
      throwsA(predicate((e) => e is ParseError && e.message == 'via was not a valid ip address')),
    );
  });
}
