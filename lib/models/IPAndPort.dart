class IPAndPort {
  String ip;
  int port;

  IPAndPort({this.ip, this.port});

  @override
  String toString() {
    if (ip.contains(':')) {
      return '[$ip]:$port';
    }

    return '$ip:$port';
  }

  String toJson() {
    return toString();
  }

  IPAndPort.fromString(String val) {
    //TODO: Uri.parse is as close as I could get to parsing both ipv4 and v6 addresses with a port without bringing a whole mess of code into here
    final uri = Uri.parse("ugh://$val");
    this.ip = uri.host;
    this.port = uri.port;
  }
}
