import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/models/firewall_rule.dart';

void main() {
  group('FirewallRule.fromJson', () {
    test('parses defaults when fields are missing', () {
      final rule = FirewallRule.fromJson({});
      expect(rule.protocol, 'any');
      expect(rule.startPort, 0);
      expect(rule.endPort, 0);
      expect(rule.fragment, false);
      expect(rule.host, isNull);
      expect(rule.groups, isNull);
      expect(rule.localCidr, isNull);
      expect(rule.remoteCidr, isNull);
      expect(rule.caName, isNull);
      expect(rule.caSha, isNull);
    });

    test('parses a basic any/any rule', () {
      final rule = FirewallRule.fromJson({
        'protocol': 'any',
        'startPort': 0,
        'endPort': 0,
        'host': 'any',
      });
      expect(rule.protocol, 'any');
      expect(rule.startPort, 0);
      expect(rule.endPort, 0);
      expect(rule.host, 'any');
    });

    test('parses a port range with groups', () {
      final rule = FirewallRule.fromJson({
        'protocol': 'tcp',
        'startPort': 80,
        'endPort': 443,
        'groups': ['eng', 'ops'],
      });
      expect(rule.protocol, 'tcp');
      expect(rule.startPort, 80);
      expect(rule.endPort, 443);
      expect(rule.groups, ['eng', 'ops']);
    });

    test('parses fragment rule', () {
      final rule = FirewallRule.fromJson({
        'protocol': 'any',
        'startPort': 0,
        'endPort': 0,
        'fragment': true,
        'host': 'any',
      });
      expect(rule.fragment, true);
    });

    test('parses cidr fields', () {
      final rule = FirewallRule.fromJson({
        'protocol': 'any',
        'startPort': 0,
        'endPort': 0,
        'remoteCidr': '10.0.0.0/8',
        'localCidr': '192.168.0.0/16',
      });
      expect(rule.remoteCidr?.toString(), '10.0.0.0/8');
      expect(rule.localCidr?.toString(), '192.168.0.0/16');
    });

    test('ignores empty cidr strings', () {
      final rule = FirewallRule.fromJson({
        'remoteCidr': '',
        'localCidr': '',
      });
      expect(rule.remoteCidr, isNull);
      expect(rule.localCidr, isNull);
    });

    test('parses caName and caSha', () {
      final rule = FirewallRule.fromJson({
        'protocol': 'any',
        'startPort': 0,
        'endPort': 0,
        'caName': 'my-ca',
        'caSha': 'deadbeef',
      });
      expect(rule.caName, 'my-ca');
      expect(rule.caSha, 'deadbeef');
    });
  });

  group('FirewallRule.toJson', () {
    test('serializes a basic any/any rule', () {
      final rule = FirewallRule(protocol: 'any', startPort: 0, endPort: 0, host: 'any');
      final json = rule.toJson();
      expect(json['protocol'], 'any');
      expect(json['startPort'], 0);
      expect(json['endPort'], 0);
      expect(json['host'], 'any');
      expect(json.containsKey('fragment'), false);
    });

    test('serializes a fragment rule', () {
      final rule = FirewallRule(protocol: 'any', fragment: true, host: 'any');
      final json = rule.toJson();
      expect(json['fragment'], true);
    });

    test('serializes groups and cidrs', () {
      final rule = FirewallRule(
        protocol: 'tcp',
        startPort: 80,
        endPort: 443,
        groups: ['eng', 'ops'],
      );
      final json = rule.toJson();
      expect(json['protocol'], 'tcp');
      expect(json['startPort'], 80);
      expect(json['endPort'], 443);
      expect(json['groups'], ['eng', 'ops']);
    });

    test('round-trips through fromJson', () {
      final original = FirewallRule(
        protocol: 'tcp',
        startPort: 80,
        endPort: 443,
        host: 'any',
        groups: ['eng'],
        caName: 'my-ca',
        caSha: 'deadbeef',
      );
      final roundTripped = FirewallRule.fromJson(original.toJson());
      expect(roundTripped.protocol, original.protocol);
      expect(roundTripped.startPort, original.startPort);
      expect(roundTripped.endPort, original.endPort);
      expect(roundTripped.host, original.host);
      expect(roundTripped.groups, original.groups);
      expect(roundTripped.caName, original.caName);
      expect(roundTripped.caSha, original.caSha);
    });
  });
}
