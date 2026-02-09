import 'ip_and_port.dart';

class Hostmap {
  String nebulaIp;
  List<IPAndPort> destinations;
  bool lighthouse;

  Hostmap({required this.nebulaIp, required this.destinations, required this.lighthouse});
}
