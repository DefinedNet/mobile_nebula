import 'package:mobile_nebula/errors/parse_error.dart';
import 'package:mobile_nebula/validators/ip_validator.dart';
import 'package:yaml/yaml.dart';

import 'cidr.dart';

class Gateway {
  String gateway;
  int weight;

  Gateway({required this.gateway, this.weight = 1});

  factory Gateway.fromJson(Map<String, dynamic> json) {
    return Gateway(gateway: json['gateway'] as String? ?? '', weight: (json['weight'] as num?)?.toInt() ?? 1);
  }

  Map<String, dynamic> toJson() => {'gateway': gateway, 'weight': weight};
}

class UnsafeRoute {
  String? route;
  List<Gateway> via;

  UnsafeRoute({this.route, List<Gateway>? via}) : via = via ?? [];

  factory UnsafeRoute.fromYaml(dynamic yaml) {
    if (yaml is! YamlMap) {
      throw ParseError('unsafe route was not a map');
    }

    final unsafeRoute = UnsafeRoute();
    if (yaml.containsKey('route') && yaml['route'] is String) {
      try {
        unsafeRoute.route = CIDR.fromString(yaml['route'] as String).toString();
      } on ParseError catch (err) {
        err.message = 'unable to parse CIDR from route: ${err.message}';
        rethrow;
      }
    } else {
      throw ParseError('route was not a string');
    }

    final viaValue = yaml['via'];
    if (viaValue is String) {
      // Legacy single-gateway string format
      var (valid, _) = ipValidator(viaValue);
      if (!valid) {
        throw ParseError('via was not a valid ip address');
      }
      unsafeRoute.via = [Gateway(gateway: viaValue)];
    } else if (viaValue is YamlList) {
      // New multi-gateway list format: [{gateway: ip, weight: n}, ...]
      final gateways = <Gateway>[];
      for (final item in viaValue) {
        if (item is! YamlMap) {
          throw ParseError('via list item was not a map');
        }
        final gatewayStr = item['gateway'];
        if (gatewayStr is! String) {
          throw ParseError('gateway was not a string');
        }
        var (valid, _) = ipValidator(gatewayStr);
        if (!valid) {
          throw ParseError('gateway was not a valid ip address');
        }
        final weight = item['weight'];
        gateways.add(Gateway(gateway: gatewayStr, weight: weight is int ? weight : 1));
      }
      if (gateways.isEmpty) {
        throw ParseError('via list was empty');
      }
      unsafeRoute.via = gateways;
    } else {
      throw ParseError('via was not a string');
    }

    return unsafeRoute;
  }

  factory UnsafeRoute.fromJson(Map<String, dynamic> json) {
    final viaRaw = json['via'];
    List<Gateway> gateways;
    if (viaRaw is String) {
      // Legacy format: single gateway stored as plain string
      gateways = [Gateway(gateway: viaRaw)];
    } else if (viaRaw is List) {
      gateways = viaRaw.map((e) => Gateway.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } else {
      gateways = [];
    }
    return UnsafeRoute(route: json['route'] as String?, via: gateways);
  }

  Map<String, dynamic> toJson() {
    return {'route': route, 'via': via.map((g) => g.toJson()).toList()};
  }
}
