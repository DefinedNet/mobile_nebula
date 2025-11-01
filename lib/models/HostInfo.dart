import 'package:mobile_nebula/models/Certificate.dart';

class HostInfo {
  List<String> vpnAddrs;
  int localIndex;
  int remoteIndex;
  List<UDPAddress> remoteAddresses;
  Certificate? cert;
  UDPAddress? currentRemote;
  int messageCounter;

  HostInfo({
    required this.vpnAddrs,
    required this.localIndex,
    required this.remoteIndex,
    required this.remoteAddresses,
    required this.messageCounter,
    this.cert,
    this.currentRemote,
  });

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

    addrs = json['vpnAddrs'];
    List<String> vpnAddrs = [];
    addrs?.forEach((val) {
      if (val is String) {
        vpnAddrs.add(val);
      }
    });

    return HostInfo(
      vpnAddrs: vpnAddrs,
      localIndex: json['localIndex'],
      remoteIndex: json['remoteIndex'],
      remoteAddresses: remoteAddresses,
      messageCounter: json['messageCounter'],
      cert: cert,
      currentRemote: currentRemote,
    );
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
