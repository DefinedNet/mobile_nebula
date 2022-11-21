import 'package:mobile_nebula/models/Certificate.dart';

class HostInfo {
  String vpnIp;
  int localIndex;
  int remoteIndex;
  List<UDPAddress> remoteAddresses;
  int cachedPackets;
  Certificate? cert;
  UDPAddress? currentRemote;
  int messageCounter;

  HostInfo({
    required this.vpnIp,
    required this.localIndex,
    required this.remoteIndex,
    required this.remoteAddresses,
    required this.cachedPackets,
    required this.messageCounter,
    this.cert,
    this.currentRemote,
  });

  factory HostInfo.fromJson(Map<String, dynamic> json) {
    UDPAddress? currentRemote;
    if (json['currentRemote'] != null) {
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
      vpnIp: json['vpnIp'],
      localIndex: json['localIndex'],
      remoteIndex: json['remoteIndex'],
      remoteAddresses: remoteAddresses,
      cachedPackets: json['cachedPackets'],
      messageCounter: json['messageCounter'],
      cert: cert,
      currentRemote: currentRemote,
    );
  }
}

class UDPAddress {
  String ip;
  int port;

  @override
  String toString() {
    // Simple check on if nebula told us about a v4 or v6 ip address
    if (ip.contains(':')) {
      return '[$ip]:$port';
    }

    return '$ip:$port';
  }

  UDPAddress.fromJson(Map<String, dynamic> json)
      : ip = json['ip'],
        port = json['port'];
}
