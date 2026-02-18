import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:mobile_nebula/errors/parse_error.dart';
import 'package:mobile_nebula/models/hostinfo.dart';
import 'package:mobile_nebula/models/ip_and_port.dart';
import 'package:mobile_nebula/models/unsafe_route.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:mobile_nebula/validators/ip_validator.dart';
import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

import 'certificate.dart';
import 'static_hosts.dart';

var uuid = Uuid();
final _log = Logger('site');

final _validLogLevels = ['panic', 'fatal', 'error', 'warning', 'info', 'debug'];
final _validCiphers = ['aes', 'chachapoly'];

class Site {
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');
  late EventChannel _updates;
  late StreamSubscription<dynamic> _updateSubscription;

  /// Signals that something about this site has changed. onError is called with an error string if there was an error
  final StreamController _change = StreamController.broadcast();

  // Identifiers
  late String name;
  late String id;

  // static_host_map
  late Map<String, StaticHost> staticHostmap;
  late List<UnsafeRoute> unsafeRoutes;

  // pki fields
  late List<CertificateInfo> ca;
  String? key;
  late CertificateInfo? certInfo;

  // lighthouse options
  late int lhDuration; // in seconds

  // listen settings
  late int port;
  late int mtu;

  late String cipher;
  late int sortKey;
  late bool connected;
  late String status;
  late String logFile;
  late String logVerbosity;
  late List<String> dnsResolvers;

  late bool managed;
  // The following fields are present when managed = true
  late String? rawConfig;
  late DateTime? lastManagedUpdate;

  // A list of errors encountered while loading the site
  late List<String> errors;

  Site({
    this.name = '',
    String? id,
    Map<String, StaticHost>? staticHostmap,
    List<CertificateInfo>? ca,
    this.certInfo,
    this.lhDuration = 0,
    this.port = 0,
    this.cipher = "aes",
    this.sortKey = 0,
    this.mtu = 1300,
    this.connected = false,
    this.status = '',
    this.logFile = '',
    this.logVerbosity = 'info',
    List<String>? errors,
    List<UnsafeRoute>? unsafeRoutes,
    this.managed = false,
    this.rawConfig,
    this.lastManagedUpdate,
    List<String>? dnsResolvers,
  }) {
    this.id = id ?? uuid.v4();
    this.staticHostmap = staticHostmap ?? {};
    this.ca = ca ?? [];
    this.errors = errors ?? [];
    this.unsafeRoutes = unsafeRoutes ?? [];
    this.dnsResolvers = dnsResolvers ?? [];

    //TODO: I think this plays well with new saved sites because we should be recreating it on the main screen
    // However it might not work on the site details page with the logs button.
    // Basically we might need to make this a function and have save() call it on success
    if (id != null) {
      _updates = EventChannel('net.defined.nebula/${this.id}');
      _updateSubscription = _updates.receiveBroadcastStream().listen(
        (d) {
          try {
            _updateFromJson(d);
            _change.add(null);
          } catch (err, stackTrace) {
            //TODO: handle the error
            _log.severe("Got an error on the broadcast stream", err, stackTrace);
          }
        },
        onError: (err) {
          _updateFromJson(err.details);
          var error = err as PlatformException;
          _change.addError(error.message ?? 'An unexpected error occurred');
        },
      );
    }
  }

  factory Site.fromJson(Map<String, dynamic> json) {
    var decoded = Site._fromJson(json);
    return Site(
      name: decoded["name"],
      id: decoded['id'],
      staticHostmap: decoded['staticHostmap'],
      ca: decoded['ca'],
      certInfo: decoded['certInfo'],
      lhDuration: decoded['lhDuration'],
      port: decoded['port'],
      cipher: decoded['cipher'],
      sortKey: decoded['sortKey'],
      mtu: decoded['mtu'],
      connected: decoded['connected'],
      status: decoded['status'],
      logFile: decoded['logFile'],
      logVerbosity: decoded['logVerbosity'],
      errors: decoded['errors'],
      unsafeRoutes: decoded['unsafeRoutes'],
      managed: decoded['managed'],
      rawConfig: decoded['rawConfig'],
      lastManagedUpdate: decoded['lastManagedUpdate'],
      dnsResolvers: decoded['dnsResolvers'],
    );
  }

  static Future<Site> fromYaml(dynamic yaml) async {
    if (yaml is! YamlMap) {
      throw ParseError('site config was not a yaml map');
    }

    final site = Site();
    var lighthouses = _fromYamlLighthouse(site, yaml);
    _fromYamlStaticHostmap(site, lighthouses, yaml);
    _fromYamlUnsafeRoutes(site, yaml);
    _fromYamlCipher(site, yaml);
    _fromYamlTun(site, yaml);
    _fromYamlListen(site, yaml);
    _fromYamlLogging(site, yaml);
    await _fromYamlPki(site, platform, yaml);

    //TODO: dns resolvers aren't a thing in nebula config today, should we support them here?
    //TODO: any lighthouses that weren't added to site.staticHostmap should be added now with 0 destinations
    return site;
  }

  void _updateFromJson(String json) {
    var decoded = Site._fromJson(jsonDecode(json));
    name = decoded["name"];
    id = decoded['id']; // TODO update EventChannel
    staticHostmap = decoded['staticHostmap'];
    ca = decoded['ca'];
    certInfo = decoded['certInfo'];
    lhDuration = decoded['lhDuration'];
    port = decoded['port'];
    cipher = decoded['cipher'];
    sortKey = decoded['sortKey'];
    mtu = decoded['mtu'];
    connected = decoded['connected'];
    status = decoded['status'];
    logFile = decoded['logFile'];
    logVerbosity = decoded['logVerbosity'];
    errors = decoded['errors'];
    unsafeRoutes = decoded['unsafeRoutes'];
    managed = decoded['managed'];
    rawConfig = decoded['rawConfig'];
    lastManagedUpdate = decoded['lastManagedUpdate'];
    dnsResolvers = decoded['dnsResolvers'];
  }

  static Map<String, dynamic> _fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> rawHostmap = json['staticHostmap'];
    Map<String, StaticHost> staticHostmap = {};
    rawHostmap.forEach((key, val) {
      staticHostmap[key] = StaticHost.fromJson(val);
    });

    List<dynamic> rawUnsafeRoutes = json['unsafeRoutes'];
    List<UnsafeRoute> unsafeRoutes = [];
    for (var val in rawUnsafeRoutes) {
      unsafeRoutes.add(UnsafeRoute.fromJson(val));
    }

    List<dynamic> rawDnsResolvers = json['dnsResolvers'] ?? [];
    List<String> dnsResolvers = [];
    for (var val in rawDnsResolvers) {
      dnsResolvers.add(val.toString());
    }

    List<dynamic> rawCA = json['ca'];
    List<CertificateInfo> ca = [];
    for (var val in rawCA) {
      ca.add(CertificateInfo.fromJson(val));
    }

    CertificateInfo? certInfo;
    if (json['cert'] != null) {
      certInfo = CertificateInfo.fromJson(json['cert']);
    }

    List<dynamic> rawErrors = json["errors"];
    List<String> errors = [];
    for (var error in rawErrors) {
      errors.add(error);
    }

    return {
      "name": json["name"],
      "id": json['id'],
      "staticHostmap": staticHostmap,
      "ca": ca,
      "certInfo": certInfo,
      "lhDuration": json['lhDuration'],
      "port": json['port'],
      "cipher": json['cipher'],
      "sortKey": json['sortKey'],
      "mtu": json['mtu'],
      "connected": json['connected'] ?? false,
      "status": json['status'] ?? "",
      "logFile": json['logFile'],
      "logVerbosity": json['logVerbosity'],
      "errors": errors,
      "unsafeRoutes": unsafeRoutes,
      "managed": json['managed'] ?? false,
      "rawConfig": json['rawConfig'],
      "lastManagedUpdate": json["lastManagedUpdate"] == null ? null : DateTime.parse(json["lastManagedUpdate"]),
      "dnsResolvers": dnsResolvers,
    };
  }

  Stream onChange() {
    return _change.stream;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'staticHostmap': staticHostmap,
      'unsafeRoutes': unsafeRoutes,
      'ca': ca
          .map((cert) {
            return cert.rawCert;
          })
          .join('\n'),
      'cert': certInfo?.rawCert,
      'key': key,
      'lhDuration': lhDuration,
      'port': port,
      'mtu': mtu,
      'cipher': cipher,
      'sortKey': sortKey,
      'logVerbosity': logVerbosity,
      'managed': managed,
      'rawConfig': rawConfig,
      'dnsResolvers': dnsResolvers,
    };
  }

  Future<void> save() async {
    try {
      var raw = jsonEncode(this);
      await platform.invokeMethod("saveSite", raw);
    } on PlatformException catch (err) {
      //TODO: fix this message
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  Future<String> renderConfig() async {
    try {
      var raw = jsonEncode(this);
      return await platform.invokeMethod("nebula.renderConfig", raw);
    } on PlatformException catch (err) {
      //TODO: fix this message
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  Future<void> start() async {
    try {
      await platform.invokeMethod("startSite", <String, String>{"id": id});
    } on PlatformException catch (err) {
      throw err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  Future<void> stop() async {
    try {
      await platform.invokeMethod("stopSite", <String, String>{"id": id});
    } on PlatformException catch (err) {
      //TODO: fix this message
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  Future<List<HostInfo>> listHostmap() async {
    try {
      var ret = await platform.invokeMethod("active.listIndexes", <String, String>{"id": id});
      if (ret == null || ret == "null") {
        return [];
      }

      List<dynamic> f = jsonDecode(ret);
      List<HostInfo> hosts = [];
      for (var v in f) {
        hosts.add(HostInfo.fromJson(v));
      }

      return hosts;
    } on PlatformException catch (err) {
      //TODO: fix this message
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  Future<List<HostInfo>> listPendingHostmap() async {
    try {
      var ret = await platform.invokeMethod("active.listPendingHostmap", <String, String>{"id": id});
      if (ret == null || ret == "null") {
        return [];
      }

      List<dynamic> f = jsonDecode(ret);
      List<HostInfo> hosts = [];
      for (var v in f) {
        hosts.add(HostInfo.fromJson(v));
      }

      return hosts;
    } on PlatformException catch (err) {
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  Future<Map<String, List<HostInfo>>> listAllHostmaps() async {
    try {
      var res = await Future.wait([listHostmap(), listPendingHostmap()]);
      return {"active": res[0], "pending": res[1]};
    } on PlatformException catch (err) {
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  void dispose() {
    _updateSubscription.cancel();
    _change.close();
  }

  Future<HostInfo?> getHostInfo(String vpnIp, bool pending) async {
    try {
      var ret = await platform.invokeMethod("active.getHostInfo", <String, dynamic>{
        "id": id,
        "vpnIp": vpnIp,
        "pending": pending,
      });
      final h = jsonDecode(ret);
      if (h == null) {
        return null;
      }

      return HostInfo.fromJson(h);
    } on PlatformException catch (err) {
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  Future<HostInfo?> setRemoteForTunnel(String vpnIp, String addr) async {
    try {
      var ret = await platform.invokeMethod("active.setRemoteForTunnel", <String, dynamic>{
        "id": id,
        "vpnIp": vpnIp,
        "addr": addr,
      });
      final h = jsonDecode(ret);
      if (h == null) {
        return null;
      }

      return HostInfo.fromJson(h);
    } on PlatformException catch (err) {
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  Future<bool> closeTunnel(String vpnIp) async {
    try {
      return await platform.invokeMethod("active.closeTunnel", <String, dynamic>{"id": id, "vpnIp": vpnIp});
    } on PlatformException catch (err) {
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }
}

List<String> _fromYamlLighthouse(Site site, YamlMap yaml) {
  List<String> lighthouses = [];

  if (!yaml.containsKey('lighthouse')) {
    return [];
  }

  if (yaml['lighthouse'] is! YamlMap) {
    site.errors.add('lighthouse was not a yaml map');
    return [];
  }

  final yamlLighthouse = yaml['lighthouse'] as YamlMap;
  if (yamlLighthouse.containsKey('interval')) {
    final (duration, ok) = Utils.dynamicToInt(yamlLighthouse['interval']);
    if (ok) {
      site.lhDuration = duration;
    } else {
      site.errors.add('lighthouse.interval could not be parsed as an integer');
    }
  }

  if (yamlLighthouse.containsKey('hosts')) {
    if (yamlLighthouse['hosts'] is YamlList) {
      final yamlLighthouseHosts = yamlLighthouse['hosts'] as YamlList;
      for (var s in yamlLighthouseHosts) {
        if (s is String) {
          final (valid, _) = ipValidator(s);
          if (valid) {
            lighthouses.add(s);
          } else {
            site.errors.add('lighthouse.hosts entry was not a valid ip address: $s');
          }
        } else {
          site.errors.add('lighthouse.hosts entry was not a string: $s');
        }
      }
    } else {
      site.errors.add('lighthouse.hosts was not a yaml list');
    }
  }

  return lighthouses;
}

void _fromYamlStaticHostmap(Site site, List<String> lighthouses, YamlMap yaml) {
  if (!yaml.containsKey('static_host_map')) {
    return;
  }

  if (yaml['static_host_map'] is! YamlMap) {
    site.errors.add('static_host_map was not a yaml map');
    return;
  }

  final yamlStaticHostMap = yaml['static_host_map'] as YamlMap;
  yamlStaticHostMap.forEach((yamlVpnAddr, yamlDestinations) {
    String vpnAddr = '';
    if (yamlVpnAddr is String) {
      final (valid, _) = ipValidator(yamlVpnAddr);
      if (!valid) {
        site.errors.add('invalid vpn address in static_host_map: $yamlVpnAddr');
        return;
      }
      vpnAddr = yamlVpnAddr;
    } else {
      site.errors.add('static_host_map key was not a string: $yamlVpnAddr');
      return;
    }

    List<IPAndPort> destinations = [];
    if (yamlDestinations is YamlList) {
      for (var hostPort in yamlDestinations) {
        if (hostPort is String) {
          try {
            destinations.add(IPAndPort.fromString(hostPort));
          } on ParseError catch (err) {
            site.errors.add('static_host_map destination $hostPort for $vpnAddr was not valid: ${err.message}');
          }
        } else {
          site.errors.add('static_host_map destination for $vpnAddr was not a string: $hostPort');
        }
      }
    } else {
      site.errors.add('static_host_map destinations for $vpnAddr was not a list of strings');
    }

    site.staticHostmap[vpnAddr] = StaticHost(lighthouse: lighthouses.contains(vpnAddr), destinations: destinations);
  });
}

Future<void> _fromYamlPki(Site site, MethodChannel platform, YamlMap yaml) async {
  if (!yaml.containsKey('pki')) {
    return;
  }

  if (yaml['pki'] is! YamlMap) {
    site.errors.add('pki was not a yaml map');
    return;
  }

  final yamlPki = yaml['pki'] as YamlMap;
  if (yamlPki.containsKey('key')) {
    if (yamlPki['key'] is String) {
      site.key = yamlPki['key'] as String;
    } else {
      site.errors.add('pki.key was not a string');
    }
  }

  if (yamlPki.containsKey('ca')) {
    if (yamlPki['ca'] is String) {
      try {
        var rawCaInfo = await platform.invokeMethod("nebula.parseCerts", <String, String>{
          "certs": yamlPki['ca'] as String,
        });
        List<dynamic> rawCas = jsonDecode(rawCaInfo);
        var i = 0;
        for (var rawCa in rawCas) {
          i++;
          try {
            site.ca.add(CertificateInfo.fromJson(rawCa));
          } on ParseError catch (err) {
            site.errors.add('skipping ca $i due to error: ${err.message}');
          }
        }
      } on PlatformException catch (err) {
        site.errors.add('could not parse pki.ca: ${err.message}');
      }
    } else {
      site.errors.add('pki.ca was not a string');
    }
  }

  if (yamlPki.containsKey('cert')) {
    if (yamlPki['cert'] is String) {
      try {
        var rawCertInfo = await platform.invokeMethod("nebula.parseCerts", <String, String>{
          "certs": yamlPki['cert'] as String,
        });
        List<dynamic> rawCerts = jsonDecode(rawCertInfo);
        for (var rawCert in rawCerts) {
          try {
            site.certInfo = CertificateInfo.fromJson(rawCert);
          } on ParseError catch (err) {
            site.errors.add('skipping cert due to error: ${err.message}');
          }
        }
      } on PlatformException catch (err) {
        site.errors.add('could not parse pki.cert: ${err.message}');
      }
    } else {
      site.errors.add('pki.cert was not a string');
    }
  }
}

void _fromYamlUnsafeRoutes(Site site, YamlMap yaml) {
  if (!yaml.containsKey('unsafe_routes')) {
    return;
  }

  if (yaml['unsafe_routes'] is! YamlList) {
    site.errors.add('unsafe_routes was not a yaml list');
    return;
  }

  final yamlUnsafeRoutes = yaml['unsafe_routes'] as YamlList;
  var i = 0;
  for (var yamlRoute in yamlUnsafeRoutes) {
    i++;
    try {
      site.unsafeRoutes.add(UnsafeRoute.fromYaml(yamlRoute));
    } on ParseError catch (err) {
      site.errors.add('failed to parse unsafe route $i: ${err.message}');
    }
  }
}

void _fromYamlCipher(Site site, YamlMap yaml) {
  if (!yaml.containsKey('cipher')) {
    return;
  }

  if (yaml['cipher'] is! String) {
    site.errors.add('cipher was not a string');
  }

  final yamlCipher = (yaml['cipher'] as String).toLowerCase();
  if (_validCiphers.contains(yamlCipher)) {
    site.cipher = yamlCipher;
  } else {
    site.errors.add('cipher was not valid: $yamlCipher');
  }
}

void _fromYamlTun(Site site, YamlMap yaml) {
  if (!yaml.containsKey('tun')) {
    return;
  }

  if (yaml['tun'] is! YamlMap) {
    site.errors.add('tun was not a yaml map');
    return;
  }

  final yamlTun = yaml['tun'] as YamlMap;
  if (yamlTun.containsKey('mtu')) {
    final (mtu, valid) = Utils.dynamicToInt(yamlTun['mtu']);
    if (valid) {
      site.mtu = mtu;
    } else {
      site.errors.add('tun.mtu was not a number: ${yamlTun['mtu']}');
    }
  }
}

void _fromYamlListen(Site site, YamlMap yaml) {
  if (!yaml.containsKey('listen')) {
    return;
  }

  if (yaml['listen'] is! YamlMap) {
    site.errors.add('listen was not a yaml map');
    return;
  }

  final yamlListen = yaml['listen'] as YamlMap;
  if (yamlListen.containsKey('port')) {
    final (port, valid) = Utils.dynamicToInt(yamlListen['port']);
    if (valid) {
      site.port = port;
    } else {
      site.errors.add('listen.port was not a number: ${yamlListen['port']}');
    }
  }
}

void _fromYamlLogging(Site site, YamlMap yaml) {
  if (!yaml.containsKey('logging')) {
    return;
  }

  if (yaml['logging'] is! YamlMap) {
    site.errors.add('logging was not a yaml map');
    return;
  }

  final yamlLogging = yaml['logging'] as YamlMap;
  if (!yamlLogging.containsKey('level')) {
    return;
  }

  if (yamlLogging['level'] is! String) {
    site.errors.add('logging.level was not a string');
    return;
  }

  final yamlLevel = (yamlLogging['level'] as String).toLowerCase();
  if (_validLogLevels.contains(yamlLevel)) {
    site.logVerbosity = yamlLevel;
  } else {
    site.errors.add('logging.level was not valid: $yamlLevel');
  }
}
