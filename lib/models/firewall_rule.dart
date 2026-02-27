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

  factory FirewallRule.fromJson(Map<String, dynamic> json) {
    return FirewallRule(
      protocol: json['protocol'] ?? 'any',
      startPort: json['startPort'] ?? 0,
      endPort: json['endPort'] ?? 0,
      fragment: json['fragment'] ?? false,
      host: json['host'],
      groups: json['groups'] != null ? List<String>.from(json['groups']) : null,
      localCidr: (json['localCidr'] != null && json['localCidr'] != '') ? CIDR.fromString(json['localCidr']) : null,
      remoteCidr: (json['remoteCidr'] != null && json['remoteCidr'] != '') ? CIDR.fromString(json['remoteCidr']) : null,
      caName: json['caName'],
      caSha: json['caSha'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol,
      'startPort': startPort,
      'endPort': endPort,
      if (fragment == true) 'fragment': true,
      'host': host,
      'groups': groups,
      'localCidr': localCidr?.toJson(),
      'remoteCidr': remoteCidr?.toJson(),
      'caName': caName,
      'caSha': caSha,
    };
  }
}
