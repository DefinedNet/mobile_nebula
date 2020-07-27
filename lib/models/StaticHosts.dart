import 'IPAndPort.dart';

class StaticHost {
  bool lighthouse;
  List<IPAndPort> destinations;

  StaticHost({this.lighthouse, this.destinations});

  StaticHost.fromJson(Map<String, dynamic> json) {
    lighthouse = json['lighthouse'];

    var list = json['destinations'] as List<dynamic>;
    var result = List<IPAndPort>();

    list.forEach((item) {
      result.add(IPAndPort.fromString(item));
    });

    destinations = result;
  }

  Map<String, dynamic> toJson() {
    return {
      'lighthouse': lighthouse,
      'destinations': destinations,
    };
  }
}
