class CIDR {
  CIDR({required this.ip, required this.bits});

  String ip;
  int bits;

  @override
  String toString() {
    return '$ip/$bits';
  }

  String toJson() {
    return toString();
  }

  factory CIDR.fromString(String val) {
    final parts = val.split('/');
    if (parts.length != 2) {
      throw 'Invalid CIDR string';
    }

    return CIDR(
      ip: parts[0],
      bits: int.parse(parts[1]),
    );
  }
}
