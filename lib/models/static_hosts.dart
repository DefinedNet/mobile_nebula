import 'ip_and_port.dart';

class StaticHost {
  bool lighthouse;
  List<IPAndPort> destinations;

  StaticHost({required this.lighthouse, required this.destinations});

  factory StaticHost.fromJson(Map<String, dynamic> json) {
    var list = json['destinations'] as List<dynamic>;
    var result = <IPAndPort>[];

    for (var item in list) {
      result.add(IPAndPort.fromString(item));
    }

    return StaticHost(lighthouse: json['lighthouse'], destinations: result);
  }

  Map<String, dynamic> toJson() {
    return {'lighthouse': lighthouse, 'destinations': destinations};
  }
}
