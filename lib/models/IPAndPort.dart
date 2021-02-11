class IPAndPort {
  IPAndPort({this.ip, this.port}) {
    if (ip != null && ip.contains(':')) {
      this._v6 = true;
    }
  }

  String ip;
  int port;
  bool _v6 = false;

  @override
  String toString() {
    if (_v6) {
      return '[$ip]:$port';
    }

    return '$ip:$port';
  }

  String toJson() {
    return toString();
  }

  IPAndPort.fromString(String val) {
    //TODO: This is a horrible ip and port parsing scheme, dart lacks a proper one, need to port a real one from another language
    final parts = val.split(':');
    if (parts.length < 2) {
      throw 'Invalid IPAndPort string';
    }

    port = int.parse(parts[parts.length - 1]);

    if (parts.length > 2) {
      _v6 = true;
      ip = parts.getRange(0, parts.length - 2).join(':');
    } else {
      ip = parts[0];
    }
  }
}
