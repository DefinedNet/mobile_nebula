import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/models/firewall_rule.dart';

void main() {
  group('FirewallRule.fromJson', () {
    test('parses a basic rule', () {
      final rule = FirewallRule.fromJson({'port': '443', 'proto': 'tcp', 'host': 'any'});

      expect(rule.port, '443');
      expect(rule.proto, 'tcp');
      expect(rule.host, 'any');
    });

    test('defaults port and proto to any', () {
      final rule = FirewallRule.fromJson({});
      expect(rule.port, 'any');
      expect(rule.proto, 'any');
    });

    test('parses port range', () {
      final rule = FirewallRule.fromJson({'port': '80-443', 'proto': 'tcp'});
      expect(rule.port, '80-443');
    });

    test('parses fragment port', () {
      final rule = FirewallRule.fromJson({'port': 'fragment', 'proto': 'icmp'});
      expect(rule.port, 'fragment');
    });

    test('maps cidr to cidr and local_cidr to localCidr', () {
      final rule = FirewallRule.fromJson({
        'port': 'any',
        'proto': 'any',
        'cidr': '10.0.0.0/24',
        'local_cidr': '192.168.1.0/24',
      });

      expect(rule.cidr, '10.0.0.0/24');
      expect(rule.localCidr, '192.168.1.0/24');
    });

    test('maps ca_name and ca_sha', () {
      final rule = FirewallRule.fromJson({'port': 'any', 'proto': 'any', 'ca_name': 'myCA', 'ca_sha': 'abc123'});

      expect(rule.caName, 'myCA');
      expect(rule.caSha, 'abc123');
    });

    test('merges singular group into groups', () {
      final rule = FirewallRule.fromJson({'port': 'any', 'proto': 'any', 'group': 'servers'});

      expect(rule.groups, ['servers']);
    });

    test('groups takes precedence over group when both are present', () {
      final rule = FirewallRule.fromJson({
        'port': 'any',
        'proto': 'any',
        'groups': ['web', 'api'],
        'group': 'servers',
      });

      expect(rule.groups, ['web', 'api']);
    });

    test('handles groups as a single string', () {
      final rule = FirewallRule.fromJson({
        'port': 'any',
        'proto': 'any',
        'groups': 'web',
      });

      expect(rule.groups, ['web']);
    });

    test('handles groups without singular group', () {
      final rule = FirewallRule.fromJson({
        'port': 'any',
        'proto': 'any',
        'groups': ['web', 'api'],
      });

      expect(rule.groups, ['web', 'api']);
    });

    test('migrates code to port when port is absent', () {
      final rule = FirewallRule.fromJson({'code': '8', 'proto': 'icmp'});
      expect(rule.port, '8');
    });

    test('migrates code to port when port is any', () {
      final rule = FirewallRule.fromJson({'port': 'any', 'code': '8', 'proto': 'icmp'});
      expect(rule.port, '8');
    });

    test('port wins over code when port is explicitly set', () {
      final rule = FirewallRule.fromJson({'port': '443', 'code': '8', 'proto': 'tcp'});
      expect(rule.port, '443');
    });
  });

  group('FirewallRule.toJson', () {
    test('produces nebula config format', () {
      final rule = FirewallRule(port: '443', proto: 'tcp', host: 'any');

      expect(rule.toJson(), {'port': '443', 'proto': 'tcp', 'host': 'any'});
    });

    test('maps localCidr to local_cidr and caName to ca_name', () {
      final rule = FirewallRule(
        port: 'any',
        proto: 'any',
        localCidr: '192.168.1.0/24',
        cidr: '10.0.0.0/24',
        caName: 'myCA',
        caSha: 'abc123',
      );

      final json = rule.toJson();
      expect(json['local_cidr'], '192.168.1.0/24');
      expect(json['cidr'], '10.0.0.0/24');
      expect(json['ca_name'], 'myCA');
      expect(json['ca_sha'], 'abc123');
    });

    test('omits null fields', () {
      final rule = FirewallRule(port: 'any', proto: 'any');
      final json = rule.toJson();

      expect(json.containsKey('host'), false);
      expect(json.containsKey('groups'), false);
      expect(json.containsKey('cidr'), false);
      expect(json.containsKey('local_cidr'), false);
      expect(json.containsKey('ca_name'), false);
      expect(json.containsKey('ca_sha'), false);
      expect(json.containsKey('code'), false);
    });

    test('does not emit code field', () {
      final rule = FirewallRule.fromJson({'code': '8', 'proto': 'icmp'});
      final json = rule.toJson();
      expect(json.containsKey('code'), false);
      expect(json['port'], '8');
    });

    test('round-trips through fromJson/toJson', () {
      final original = {
        'port': '80-443',
        'proto': 'tcp',
        'host': 'web-server',
        'groups': ['web'],
        'cidr': '10.0.0.0/24',
        'local_cidr': '192.168.1.0/24',
        'ca_name': 'myCA',
        'ca_sha': 'abc123',
      };

      final rule = FirewallRule.fromJson(original);
      final result = rule.toJson();

      expect(result, original);
    });
  });

  group('FirewallRule.validate', () {
    test('accepts valid rules', () {
      expect(FirewallRule(port: 'any', proto: 'any').validate(), isNull);
      expect(FirewallRule(port: '443', proto: 'tcp').validate(), isNull);
      expect(FirewallRule(port: '80-443', proto: 'udp').validate(), isNull);
      expect(FirewallRule(port: 'fragment', proto: 'icmp').validate(), isNull);
      expect(FirewallRule(port: '1', proto: 'any').validate(), isNull);
      expect(FirewallRule(port: '65535', proto: 'any').validate(), isNull);
    });

    test('rejects invalid ports', () {
      expect(FirewallRule(port: 'abc', proto: 'any').validate(), isNotNull);
      expect(FirewallRule(port: '0', proto: 'any').validate(), isNotNull);
      expect(FirewallRule(port: '99999', proto: 'any').validate(), isNotNull);
      expect(FirewallRule(port: '443-80', proto: 'any').validate(), isNotNull);
      expect(FirewallRule(port: '-1', proto: 'any').validate(), isNotNull);
    });

    test('rejects invalid proto', () {
      expect(FirewallRule(port: 'any', proto: 'http').validate(), isNotNull);
      expect(FirewallRule(port: 'any', proto: '').validate(), isNotNull);
    });
  });

  group('FirewallRule.validatePort', () {
    test('validates port strings', () {
      expect(FirewallRule.validatePort('any'), isNull);
      expect(FirewallRule.validatePort('fragment'), isNull);
      expect(FirewallRule.validatePort('443'), isNull);
      expect(FirewallRule.validatePort('80-443'), isNull);
      expect(FirewallRule.validatePort('1'), isNull);
      expect(FirewallRule.validatePort('65535'), isNull);

      expect(FirewallRule.validatePort('0'), isNotNull);
      expect(FirewallRule.validatePort('65536'), isNotNull);
      expect(FirewallRule.validatePort('abc'), isNotNull);
      expect(FirewallRule.validatePort('443-80'), isNotNull);
      expect(FirewallRule.validatePort('80-80'), isNotNull);
    });
  });
}
