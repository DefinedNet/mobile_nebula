import 'package:mobile_nebula/services/utils.dart';
import 'package:yaml/yaml.dart';

import '../errors/parse_error.dart';
import 'cidr.dart';

class FirewallRule {
  String protocol;
  int startPort;
  int endPort;
  bool? fragment;
  String? host;
  List<String>? groups;
  CIDR? localCidr;
  CIDR? remoteCidr;
  String? caName;
  String? caSha;

  FirewallRule({
    this.protocol = 'any',
    this.startPort = 0,
    this.endPort = 0,
    this.fragment = false,
    this.host = 'any',
    this.groups,
    this.localCidr,
    this.remoteCidr,
    this.caName,
    this.caSha,
  });

  factory FirewallRule.fromYaml(dynamic yaml) {
    if (yaml is! YamlMap) {
      throw ParseError('input was not a yaml map');
    }

    final rule = FirewallRule();

    if (yaml.containsKey('port')) {
      final portVal = yaml['port'];
      final (maybePort, valid) = Utils.dynamicToInt(portVal);
      if (valid) {
        if (maybePort < 0 || maybePort > 65535) {
          throw ParseError('port $maybePort is out of range');
        }
        rule.startPort = maybePort;
        rule.endPort = maybePort;
      } else if (portVal is String) {
        final rawPort = portVal.toLowerCase().trim();
        if (rawPort == 'any') {
          rule.startPort = 0;
          rule.endPort = 0;
        } else if (rawPort == 'fragment') {
          rule.fragment = true;
        } else if (rawPort.contains('-')) {
          final parts = rawPort.split('-');
          if (parts.length != 2) {
            throw ParseError('invalid port range: $rawPort');
          }
          final start = int.tryParse(parts[0].trim());
          final end = int.tryParse(parts[1].trim());
          if (start == null || end == null) {
            throw ParseError('invalid port range: $rawPort');
          }
          if (start < 0 || start > 65535 || end < 0 || end > 65535) {
            throw ParseError('port range $rawPort is out of bounds');
          }
          if (start > end) {
            throw ParseError('port range start $start is greater than end $end');
          }
          rule.startPort = start;
          rule.endPort = end;
        } else {
          throw ParseError('invalid port value: $rawPort');
        }
      }
    }

    if (yaml.containsKey('proto')) {
      if (yaml['proto'] is! String) {
        throw ParseError('proto was not a string');
      }
      rule.protocol = (yaml['proto'] as String).toLowerCase().trim();
    }

    if (yaml.containsKey('host')) {
      if (yaml['host'] is! String) {
        throw ParseError('host was not a string');
      }
      rule.host = yaml['host'] as String;
    }

    if (yaml.containsKey('groups')) {
      final groupsVal = yaml['groups'];
      if (groupsVal is YamlList) {
        rule.groups = groupsVal.map((g) => g.toString()).toList();
      } else if (groupsVal is String) {
        rule.groups = [groupsVal];
      } else {
        throw ParseError('groups was not a list or string');
      }
    } else if (yaml.containsKey('group')) {
      if (yaml['group'] is! String) {
        throw ParseError('group was not a string');
      }
      rule.groups = [yaml['group'] as String];
    }

    if (yaml.containsKey('cidr')) {
      if (yaml['cidr'] is! String) {
        throw ParseError('cidr was not a string');
      }
      try {
        rule.remoteCidr = CIDR.fromString(yaml['cidr'] as String);
      } on ParseError catch (err) {
        err.message = 'unable to parse cidr: ${err.message}';
        rethrow;
      }
    }

    if (yaml.containsKey('local_cidr')) {
      if (yaml['local_cidr'] is! String) {
        throw ParseError('local_cidr was not a string');
      }
      try {
        rule.localCidr = CIDR.fromString(yaml['local_cidr'] as String);
      } on ParseError catch (err) {
        err.message = 'unable to parse local_cidr: ${err.message}';
        rethrow;
      }
    }

    if (yaml.containsKey('ca_sha')) {
      if (yaml['ca_sha'] is! String) {
        throw ParseError('ca_sha was not a string');
      }
      rule.caSha = yaml['ca_sha'] as String;
    }

    if (yaml.containsKey('ca_name')) {
      if (yaml['ca_name'] is! String) {
        throw ParseError('ca_name was not a string');
      }
      rule.caName = yaml['ca_name'] as String;
    }

    return rule;
  }

  factory FirewallRule.fromJson(Map<String, dynamic> json) {
    final rule = FirewallRule();

    rule.protocol = json['proto'] ?? 'any';

    final portVal = json['port'];
    if (portVal is String) {
      final rawPort = portVal.toLowerCase().trim();
      if (rawPort == 'fragment') {
        rule.fragment = true;
      } else if (rawPort.isEmpty || rawPort == 'any') {
        rule.startPort = 0;
        rule.endPort = 0;
      } else if (rawPort.contains('-')) {
        final parts = rawPort.split('-');
        rule.startPort = int.tryParse(parts[0].trim()) ?? 0;
        rule.endPort = int.tryParse(parts[1].trim()) ?? 0;
      } else {
        final p = int.tryParse(rawPort) ?? 0;
        rule.startPort = p;
        rule.endPort = p;
      }
    }

    rule.host = json['host'];
    if (json['groups'] != null) {
      rule.groups = List<String>.from(json['groups']);
    } else if (json['group'] != null && (json['group'] as String).isNotEmpty) {
      rule.groups = [json['group'] as String];
    }
    rule.localCidr = (json['localCidr'] != null && json['localCidr'] != '') ? CIDR.fromString(json['localCidr']) : null;
    rule.remoteCidr = (json['cidr'] != null && json['cidr'] != '') ? CIDR.fromString(json['cidr']) : null;
    rule.caName = json['caName'];
    rule.caSha = json['caSha'];

    return rule;
  }

  Map<String, dynamic> toJson() {
    String portStr;
    if (fragment == true) {
      portStr = 'fragment';
    } else if (startPort == 0 && endPort == 0) {
      portStr = 'any';
    } else if (startPort == endPort) {
      portStr = '$startPort';
    } else {
      portStr = '$startPort-$endPort';
    }

    return {
      'proto': protocol,
      'port': portStr,
      'host': host,
      'groups': groups,
      'localCidr': localCidr?.toJson(),
      'cidr': remoteCidr?.toJson(),
      'caName': caName,
      'caSha': caSha,
    };
  }
}
