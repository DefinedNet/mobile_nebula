class IPAndPort {
  String? ip;
  int? port;

  IPAndPort({this.ip, this.port});

  @override
  String toString() {
    if (ip != null && ip!.contains(':')) {
      return '[$ip]:$port';
    }

    return '$ip:$port';
  }

  String toJson() {
    return toString();
  }

  factory IPAndPort.fromString(String val) {
    //TODO: Uri.parse is as close as I could get to parsing both ipv4 and v6 addresses with a port without bringing a whole mess of code into here
    final uri = Uri.parse("ugh://$val");

    return IPAndPort(
      ip: uri.host,
      port: uri.port,
    );
  }
}
