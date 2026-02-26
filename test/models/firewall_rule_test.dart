import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/errors/parse_error.dart';
import 'package:mobile_nebula/models/firewall_rule.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('FirewallRule.fromYaml', () {
    test('throws when input is not a YamlMap', () {
      expect(
        () => FirewallRule.fromYaml('not a map'),
        throwsA(predicate((e) => e is ParseError && e.message == 'input was not a yaml map')),
      );
      expect(
        () => FirewallRule.fromYaml(42),
        throwsA(predicate((e) => e is ParseError && e.message == 'input was not a yaml map')),
      );
    });

    test('returns defaults when no fields are present', () {
      final rule = FirewallRule.fromYaml(loadYaml('{}'));
      expect(rule.protocol, 'any');
      expect(rule.startPort, 0);
      expect(rule.endPort, 0);
      expect(rule.fragment, false);
      expect(rule.host, 'any');
      expect(rule.groups, isNull);
      expect(rule.localCidr, isNull);
      expect(rule.remoteCidr, isNull);
      expect(rule.caName, isNull);
      expect(rule.caSha, isNull);
    });

    group('port', () {
      test('integer port', () {
        final rule = FirewallRule.fromYaml(loadYaml('port: 443'));
        expect(rule.startPort, 443);
        expect(rule.endPort, 443);
        expect(rule.fragment, false);
      });

      test('port 0', () {
        final rule = FirewallRule.fromYaml(loadYaml('port: 0'));
        expect(rule.startPort, 0);
        expect(rule.endPort, 0);
      });

      test('"any" port', () {
        final rule = FirewallRule.fromYaml(loadYaml('port: any'));
        expect(rule.startPort, 0);
        expect(rule.endPort, 0);
        expect(rule.fragment, false);
      });

      test('"fragment"', () {
        final rule = FirewallRule.fromYaml(loadYaml('port: fragment'));
        expect(rule.fragment, true);
      });

      test('port range', () {
        final rule = FirewallRule.fromYaml(loadYaml('port: 80-443'));
        expect(rule.startPort, 80);
        expect(rule.endPort, 443);
        expect(rule.fragment, false);
      });

      test('port out of range', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('port: 99999')),
          throwsA(predicate((e) => e is ParseError && e.message == 'port 99999 is out of range')),
        );
      });

      test('port range out of bounds', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('port: 80-99999')),
          throwsA(predicate((e) => e is ParseError && e.message == 'port range 80-99999 is out of bounds')),
        );
      });

      test('port range start greater than end', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('port: 443-80')),
          throwsA(predicate((e) => e is ParseError && e.message == 'port range start 443 is greater than end 80')),
        );
      });

      test('invalid port string', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('port: notaport')),
          throwsA(predicate((e) => e is ParseError && e.message == 'invalid port value: notaport')),
        );
      });
    });

    group('proto', () {
      test('parses proto', () {
        final rule = FirewallRule.fromYaml(loadYaml('proto: tcp'));
        expect(rule.protocol, 'tcp');
      });

      test('lowercases proto', () {
        final rule = FirewallRule.fromYaml(loadYaml('proto: UDP'));
        expect(rule.protocol, 'udp');
      });

      test('throws when proto is not a string', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('proto: 123')),
          throwsA(predicate((e) => e is ParseError && e.message == 'proto was not a string')),
        );
      });
    });

    group('host', () {
      test('parses host', () {
        final rule = FirewallRule.fromYaml(loadYaml('host: any'));
        expect(rule.host, 'any');
      });

      test('throws when host is not a string', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('host: 123')),
          throwsA(predicate((e) => e is ParseError && e.message == 'host was not a string')),
        );
      });
    });

    group('groups', () {
      test('parses groups list', () {
        final rule = FirewallRule.fromYaml(loadYaml('''
groups:
  - eng
  - ops
'''));
        expect(rule.groups, ['eng', 'ops']);
      });

      test('parses single group via "group" key', () {
        final rule = FirewallRule.fromYaml(loadYaml('group: eng'));
        expect(rule.groups, ['eng']);
      });

      test('"groups" takes precedence over "group"', () {
        final rule = FirewallRule.fromYaml(loadYaml('''
group: eng
groups:
  - ops
  - dev
'''));
        expect(rule.groups, ['ops', 'dev']);
      });

      test('throws when groups is not a list or string', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('groups: 123')),
          throwsA(predicate((e) => e is ParseError && e.message == 'groups was not a list or string')),
        );
      });

      test('throws when group is not a string', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('group: 123')),
          throwsA(predicate((e) => e is ParseError && e.message == 'group was not a string')),
        );
      });
    });

    group('cidr', () {
      test('parses cidr into remoteCidr', () {
        final rule = FirewallRule.fromYaml(loadYaml('cidr: 10.0.0.0/8'));
        expect(rule.remoteCidr?.ip, '10.0.0.0');
        expect(rule.remoteCidr?.bits, 8);
      });

      test('throws when cidr is not a string', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('cidr: 123')),
          throwsA(predicate((e) => e is ParseError && e.message == 'cidr was not a string')),
        );
      });

      test('throws on invalid cidr', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('cidr: notacidr')),
          throwsA(predicate((e) => e is ParseError && e.message.startsWith('unable to parse cidr:'))),
        );
      });
    });

    group('local_cidr', () {
      test('parses local_cidr into localCidr', () {
        final rule = FirewallRule.fromYaml(loadYaml('local_cidr: 192.168.1.0/24'));
        expect(rule.localCidr?.ip, '192.168.1.0');
        expect(rule.localCidr?.bits, 24);
      });

      test('throws when local_cidr is not a string', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('local_cidr: 123')),
          throwsA(predicate((e) => e is ParseError && e.message == 'local_cidr was not a string')),
        );
      });

      test('throws on invalid local_cidr', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('local_cidr: notacidr')),
          throwsA(predicate((e) => e is ParseError && e.message.startsWith('unable to parse local_cidr:'))),
        );
      });
    });

    group('ca_sha / ca_name', () {
      test('parses ca_sha', () {
        final rule = FirewallRule.fromYaml(loadYaml('ca_sha: abc123'));
        expect(rule.caSha, 'abc123');
      });

      test('throws when ca_sha is not a string', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('ca_sha: 123')),
          throwsA(predicate((e) => e is ParseError && e.message == 'ca_sha was not a string')),
        );
      });

      test('parses ca_name', () {
        final rule = FirewallRule.fromYaml(loadYaml('ca_name: my-ca'));
        expect(rule.caName, 'my-ca');
      });

      test('throws when ca_name is not a string', () {
        expect(
          () => FirewallRule.fromYaml(loadYaml('ca_name: 123')),
          throwsA(predicate((e) => e is ParseError && e.message == 'ca_name was not a string')),
        );
      });
    });

    test('parses a complete rule', () {
      final rule = FirewallRule.fromYaml(loadYaml('''
port: 80-443
proto: tcp
host: any
groups:
  - eng
  - ops
cidr: 10.0.0.0/8
local_cidr: 192.168.0.0/16
ca_sha: deadbeef
ca_name: my-ca
'''));
      expect(rule.startPort, 80);
      expect(rule.endPort, 443);
      expect(rule.fragment, false);
      expect(rule.protocol, 'tcp');
      expect(rule.host, 'any');
      expect(rule.groups, ['eng', 'ops']);
      expect(rule.remoteCidr?.toString(), '10.0.0.0/8');
      expect(rule.localCidr?.toString(), '192.168.0.0/16');
      expect(rule.caSha, 'deadbeef');
      expect(rule.caName, 'my-ca');
    });
  });
}
