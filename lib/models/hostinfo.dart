import 'package:mobile_nebula/models/certificate.dart';

class HostInfo {
  List<String> vpnAddrs;
  int localIndex;
  int remoteIndex;
  List<UDPAddress> remoteAddresses;
  Certificate? cert;
  UDPAddress? currentRemote;
  int messageCounter;

  /// Hosts we relay through to reach this one
  List<String> currentRelaysToMe;

  /// Hosts we relay for through this one
  List<String> currentRelaysThroughMe;

  HostInfo({
    required this.vpnAddrs,
    required this.localIndex,
    required this.remoteIndex,
    required this.remoteAddresses,
    required this.messageCounter,
    this.cert,
    this.currentRemote,
    this.currentRelaysToMe = const [],
    this.currentRelaysThroughMe = const [],
  });

  /// No direct remote, so traffic has to go through a relay
  bool get isRelayed => currentRemote == null && currentRelaysToMe.isNotEmpty;

  factory HostInfo.fromJson(Map<String, dynamic> json) {
    UDPAddress? currentRemote;
    if (json['currentRemote'] != "") {
      currentRemote = UDPAddress.fromJson(json['currentRemote']);
    }

    Certificate? cert;
    if (json['cert'] != null) {
      cert = Certificate.fromJson(json['cert']);
    }

    List<dynamic>? addrs = json['remoteAddrs'];
    List<UDPAddress> remoteAddresses = [];
    addrs?.forEach((val) {
      remoteAddresses.add(UDPAddress.fromJson(val));
    });

    return HostInfo(
      vpnAddrs: _stringList(json['vpnAddrs']),
      localIndex: json['localIndex'],
      remoteIndex: json['remoteIndex'],
      remoteAddresses: remoteAddresses,
      messageCounter: json['messageCounter'],
      cert: cert,
      currentRemote: currentRemote,
      currentRelaysToMe: _stringList(json['currentRelaysToMe']),
      currentRelaysThroughMe: _stringList(json['currentRelaysThroughMe']),
    );
  }

  static List<String> _stringList(dynamic json) {
    List<String> out = [];
    if (json is List<dynamic>) {
      for (var val in json) {
        if (val is String) {
          out.add(val);
        }
      }
    }

    return out;
  }
}

class UDPAddress {
  String ip;
  int port;

  UDPAddress({required this.ip, required this.port});

  @override
  String toString() {
    // Simple check on if nebula told us about a v4 or v6 ip address
    if (ip.contains(':')) {
      return '[$ip]:$port';
    }

    return '$ip:$port';
  }

  factory UDPAddress.fromJson(String json) {
    // IPv4 Address
    if (json.contains('.')) {
      var ip = json.split(':')[0];
      var port = int.parse(json.split(':')[1]);
      return UDPAddress(ip: ip, port: port);
    }

    // IPv6 Address
    var ip = json.split(']')[0].substring(1);
    var port = int.parse(json.split(']')[1].split(':')[1]);
    return UDPAddress(ip: ip, port: port);
  }
}
