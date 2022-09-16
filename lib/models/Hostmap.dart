import 'IPAndPort.dart';

class Hostmap {
  String nebulaIp;
  List<IPAndPort> destinations;
  bool lighthouse;

  Hostmap({required this.nebulaIp, required this.destinations, required this.lighthouse});
}
