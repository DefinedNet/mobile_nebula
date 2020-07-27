import 'IPAndPort.dart';

class Hostmap {
  String nebulaIp;
  List<IPAndPort> destinations;
  bool lighthouse;

  Hostmap({this.nebulaIp, this.destinations, this.lighthouse});
}
