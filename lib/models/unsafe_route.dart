import 'package:mobile_nebula/errors/parse_error.dart';
import 'package:mobile_nebula/validators/ip_validator.dart';
import 'package:yaml/yaml.dart';

import 'cidr.dart';

class UnsafeRoute {
  String? route;
  String? via;

  UnsafeRoute({this.route, this.via});

  factory UnsafeRoute.fromYaml(dynamic yaml) {
    if (yaml is! YamlMap) {
      throw ParseError('input was not a yaml map');
    }

    final unsafeRoute = UnsafeRoute();

    if (yaml['route'] is! String) {
      throw ParseError('route was not a string');
    }
    try {
      unsafeRoute.route = CIDR.fromString(yaml['route'] as String).toString();
    } on ParseError catch (err) {
      err.message = 'unable to parse CIDR from route: ${err.message}';
      rethrow;
    }

    if (yaml['via'] is! String) {
      throw ParseError('via was not a string');
    }
    final yamlVia = yaml['via'] as String;
    var (valid, _) = ipValidator(yamlVia);
    if (!valid) {
      throw ParseError('via was not a valid ip address');
    }
    unsafeRoute.via = yamlVia;

    return unsafeRoute;
  }

  factory UnsafeRoute.fromJson(Map<String, dynamic> json) {
    return UnsafeRoute(route: json['route'], via: json['via']);
  }

  Map<String, dynamic> toJson() {
    return {'route': route, 'via': via};
  }
}
