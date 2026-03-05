class FirewallRule {
  String port;
  String proto;
  String? host;
  List<String>? groups;
  String? cidr;
  String? localCidr;
  String? caName;
  String? caSha;

  FirewallRule({
    this.port = 'any',
    this.proto = 'any',
    this.host,
    this.groups,
    this.cidr,
    this.localCidr,
    this.caName,
    this.caSha,
  });

  factory FirewallRule.fromJson(Map<String, dynamic> json) {
    // 'group' and 'groups' are mutually exclusive in nebula config.
    // 'group' is a single string, 'groups' is a list. If both are present, 'groups' wins.
    List<String>? groups;
    if (json['groups'] is List) {
      groups = List<String>.from(json['groups']);
    } else if (json['groups'] is String) {
      groups = [json['groups'] as String];
    } else if (json['group'] is String) {
      groups = [json['group'] as String];
    }

    // 'code' is a deprecated alias for 'port' — migrate it transparently
    var port = (json['port'] ?? 'any').toString();
    if ((port == 'any') && json['code'] != null) {
      port = json['code'].toString();
    }

    return FirewallRule(
      port: port,
      proto: (json['proto'] ?? 'any').toString(),
      host: json['host'] as String?,
      groups: groups,
      cidr: json['cidr'] as String?,
      localCidr: json['local_cidr'] as String?,
      caName: json['ca_name'] as String?,
      caSha: json['ca_sha'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'port': port,
      'proto': proto,
      if (host != null) 'host': host,
      if (groups != null && groups!.isNotEmpty) 'groups': groups,
      if (cidr != null) 'cidr': cidr,
      if (localCidr != null) 'local_cidr': localCidr,
      if (caName != null) 'ca_name': caName,
      if (caSha != null) 'ca_sha': caSha,
    };
  }

  /// Validates the rule. Returns null if valid, or an error message.
  String? validate() {
    final portErr = validatePort(port);
    if (portErr != null) return portErr;

    if (!const ['any', 'tcp', 'udp', 'icmp'].contains(proto)) {
      return 'proto must be any, tcp, udp, or icmp';
    }

    return null;
  }

  /// Validates a port string. Returns null if valid, or an error message.
  static String? validatePort(String port) {
    if (port == 'any' || port == 'fragment') return null;

    if (port.contains('-')) {
      final parts = port.split('-');
      if (parts.length != 2) return 'invalid port range';
      final start = int.tryParse(parts[0]);
      final end = int.tryParse(parts[1]);
      if (start == null || end == null) return 'invalid port range';
      if (start < 1 || start > 65535 || end < 1 || end > 65535) {
        return 'port must be between 1 and 65535';
      }
      if (start >= end) return 'start port must be less than end port';
      return null;
    }

    final p = int.tryParse(port);
    if (p == null || p < 1 || p > 65535) {
      return 'port must be "any", "fragment", a number 1-65535, or a range';
    }
    return null;
  }
}
