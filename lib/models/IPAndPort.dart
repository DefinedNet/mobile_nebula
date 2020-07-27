class IPAndPort {
  IPAndPort({this.ip, this.port});

  String ip;
  int port;

  @override
  String toString() {
    return '$ip:$port';
  }

  String toJson() {
    return toString();
  }

  IPAndPort.fromString(String val) {
    final parts = val.split(':');
    if (parts.length != 2) {
      throw 'Invalid IPAndPort string';
    }

    ip = parts[0];
    port = int.parse(parts[1]);
  }
}
