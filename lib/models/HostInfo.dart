import 'package:mobile_nebula/models/Certificate.dart';

class HostInfo {
  String vpnIp;
  int localIndex;
  int remoteIndex;
  List<UDPAddress> remoteAddresses;
  int cachedPackets;
  Certificate cert;
  UDPAddress currentRemote;
  int messageCounter;

  HostInfo.fromJson(Map<String, dynamic> json) {
    vpnIp = json['vpnIp'];
    localIndex = json['localIndex'];
    remoteIndex = json['remoteIndex'];
    cachedPackets = json['cachedPackets'];

    if (json['currentRemote'] != null) {
      currentRemote = UDPAddress.fromJson(json['currentRemote']);
    }

    if (json['cert'] != null) {
      cert = Certificate.fromJson(json['cert']);
    }

    List<dynamic> addrs = json['remoteAddrs'];
    remoteAddresses = [];
    addrs?.forEach((val) {
      remoteAddresses.add(UDPAddress.fromJson(val));
    });

    messageCounter = json['messageCounter'];
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
