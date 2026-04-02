import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:mobile_nebula/models/hostinfo.dart';
import 'package:mobile_nebula/models/firewall_rule.dart';
import 'package:mobile_nebula/models/unsafe_route.dart';
import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

import 'certificate.dart';
import 'static_hosts.dart';

// Re-export HostInfo for use by callers that used to import it transitively
export 'package:mobile_nebula/models/hostinfo.dart';

var uuid = Uuid();
final _log = Logger('site');

class Site {
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');
  late EventChannel _updates;
  late StreamSubscription<dynamic> _updateSubscription;

  /// Signals that something about this site has changed. onError is called with an error string if there was an error
  final StreamController _change = StreamController.broadcast();

  // Identifiers
  late String name;
  late String id;
  late int sortKey;
  late int configVersion;

  // Nebula config as parsed JSON map (no private key)
  late Map<String, dynamic> rawConfig;

  // Private key — transient, only for save
  String? key;

  // Display-only (populated by native on load)
  late List<CertificateInfo> ca;
  late CertificateInfo? certInfo;
  late bool connected;
  late String status;
  late String logFile;
  late bool alwaysOn;
  late List<String> excludedApps;

  // DN management
  late bool managed;
  late DateTime? lastManagedUpdate;

  // A list of errors encountered while loading the site
  late List<String> errors;

  Site({
    this.name = '',
    String? id,
    Map<String, dynamic>? rawConfig,
    List<CertificateInfo>? ca,
    this.certInfo,
    this.sortKey = 0,
    this.configVersion = 0,
    this.connected = false,
    this.status = '',
    this.logFile = '',
    List<String>? errors,
    this.managed = false,
    this.lastManagedUpdate,
    this.alwaysOn = false,
    List<String>? excludedApps,
  }) {
    this.id = id ?? uuid.v4();
    this.rawConfig = rawConfig ?? {};
    this.ca = ca ?? [];
    this.errors = errors ?? [];
    this.excludedApps = excludedApps ?? [];

    if (id != null) {
      _updates = EventChannel('net.defined.nebula/${this.id}');
      _updateSubscription = _updates.receiveBroadcastStream().listen(
        (d) {
          try {
            _updateFromJson(d);
            _change.add(null);
          } catch (err, stackTrace) {
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

  /// Parses site JSON without constructing a full Site (no EventChannel).
  /// Useful for testing the parse/error logic.
  static Map<String, dynamic> parseJson(Map<String, dynamic> json) => _fromJson(json);

  factory Site.fromJson(Map<String, dynamic> json) {
    var decoded = Site._fromJson(json);
    return Site(
      name: decoded["name"],
      id: decoded['id'],
      rawConfig: decoded['rawConfig'],
      ca: decoded['ca'],
      certInfo: decoded['certInfo'],
      sortKey: decoded['sortKey'],
      configVersion: decoded['configVersion'],
      connected: decoded['connected'],
      status: decoded['status'],
      logFile: decoded['logFile'],
      errors: decoded['errors'],
      managed: decoded['managed'],
      lastManagedUpdate: decoded['lastManagedUpdate'],
      alwaysOn: decoded['alwaysOn'],
      excludedApps: decoded['excludedApps'],
    );
  }

  static Future<Site> fromYaml(dynamic yaml) async {
    if (yaml is! YamlMap) {
      throw FormatException('site config was not a yaml map');
    }

    final rawConfig = _yamlToMap(yaml);

    // Extract and remove pki.key from rawConfig
    String? key;
    if (rawConfig['pki'] is Map<String, dynamic>) {
      final pki = rawConfig['pki'] as Map<String, dynamic>;
      if (pki['key'] is String) {
        key = pki['key'] as String;
      }
      pki.remove('key');
    }

    // Parse certs for display via native
    List<CertificateInfo> ca = [];
    CertificateInfo? certInfo;
    List<String> errors = [];

    if (rawConfig['pki'] is Map<String, dynamic>) {
      final pki = rawConfig['pki'] as Map<String, dynamic>;

      if (pki['ca'] is String) {
        try {
          var rawCaInfo = await platform.invokeMethod("nebula.parseCerts", <String, String>{
            "certs": pki['ca'] as String,
          });
          List<dynamic> rawCas = jsonDecode(rawCaInfo);
          var i = 0;
          for (var rawCa in rawCas) {
            i++;
            try {
              ca.add(CertificateInfo.fromJson(rawCa));
            } catch (err) {
              errors.add('skipping ca $i due to error: $err');
            }
          }
        } on PlatformException catch (err) {
          errors.add('could not parse pki.ca: ${err.message}');
        }
      }

      if (pki['cert'] is String) {
        try {
          var rawCertInfo = await platform.invokeMethod("nebula.parseCerts", <String, String>{
            "certs": pki['cert'] as String,
          });
          List<dynamic> rawCerts = jsonDecode(rawCertInfo);
          for (var rawCert in rawCerts) {
            try {
              certInfo = CertificateInfo.fromJson(rawCert);
            } catch (err) {
              errors.add('skipping cert due to error: $err');
            }
          }
        } on PlatformException catch (err) {
          errors.add('could not parse pki.cert: ${err.message}');
        }
      }
    }

    return Site(rawConfig: rawConfig, ca: ca, certInfo: certInfo, errors: errors)..key = key;
  }

  void _updateFromJson(String json) {
    var decoded = Site._fromJson(jsonDecode(json));
    name = decoded["name"];
    id = decoded['id'];
    rawConfig = decoded['rawConfig'];
    ca = decoded['ca'];
    certInfo = decoded['certInfo'];
    sortKey = decoded['sortKey'];
    configVersion = decoded['configVersion'];
    connected = decoded['connected'];
    status = decoded['status'];
    logFile = decoded['logFile'];
    errors = decoded['errors'];
    managed = decoded['managed'];
    lastManagedUpdate = decoded['lastManagedUpdate'];
    alwaysOn = decoded['alwaysOn'];
    excludedApps = decoded['excludedApps'];
  }

  static Map<String, dynamic> _fromJson(Map<String, dynamic> json) {
    // Parse rawConfig from JSON string to map
    Map<String, dynamic> rawConfig = {};
    List<String> rawConfigErrors = [];
    if (json['rawConfig'] is String && (json['rawConfig'] as String).isNotEmpty) {
      try {
        rawConfig = Map<String, dynamic>.from(jsonDecode(json['rawConfig']));
      } catch (err) {
        rawConfigErrors.add('Failed to parse rawConfig: $err');
      }
    }

    List<dynamic> rawExcludedApps = json['excludedApps'] ?? [];
    List<String> excludedApps = [];
    for (var val in rawExcludedApps) {
      excludedApps.add(val.toString());
    }

    List<dynamic> rawCA = json['ca'] ?? [];
    List<CertificateInfo> ca = [];
    for (var val in rawCA) {
      ca.add(CertificateInfo.fromJson(val));
    }

    CertificateInfo? certInfo;
    if (json['cert'] != null) {
      certInfo = CertificateInfo.fromJson(json['cert']);
    }

    List<dynamic> rawErrors = json["errors"] ?? [];
    List<String> errors = List<String>.from(rawConfigErrors);
    for (var error in rawErrors) {
      errors.add(error);
    }

    return {
      "name": json["name"],
      "id": json['id'],
      "rawConfig": rawConfig,
      "ca": ca,
      "certInfo": certInfo,
      "sortKey": json['sortKey'] ?? 0,
      "configVersion": json['configVersion'] ?? 0,
      "connected": json['connected'] ?? false,
      "status": json['status'] ?? "",
      "logFile": json['logFile'] ?? "",
      "errors": errors,
      "managed": json['managed'] ?? false,
      "lastManagedUpdate": json["lastManagedUpdate"] == null ? null : DateTime.parse(json["lastManagedUpdate"]),
      "alwaysOn": json['alwaysOn'] ?? false,
      "excludedApps": excludedApps,
    };
  }

  Stream onChange() {
    return _change.stream;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'sortKey': sortKey,
      'configVersion': configVersion,
      'managed': managed,
      'rawConfig': jsonEncode(rawConfig),
      'key': key,
      'alwaysOn': alwaysOn,
      'excludedApps': excludedApps,
    };
  }

  // Convenience getters for UI — read from rawConfig
  int get port => _getConfigInt(['listen', 'port']) ?? 0;
  int get mtu => _getConfigInt(['tun', 'mtu']) ?? 1300;
  String get cipher => _getConfigString(['cipher']) ?? 'aes';
  String get logVerbosity => _getConfigString(['logging', 'level']) ?? 'info';

  /// Updates the certificate and private key, syncing the raw PEM into rawConfig.
  void setCertificate(CertificateInfo info, String privateKey) {
    certInfo = info;
    key = privateKey;
    if (info.rawCert != null) {
      _setConfig(['pki', 'cert'], info.rawCert);
    }
  }

  /// Updates the CA list, syncing the raw PEM strings into rawConfig.
  void setCertificateAuthorities(List<CertificateInfo> cas) {
    ca = cas;
    final pem = cas.where((c) => c.rawCert != null).map((c) => c.rawCert!).join('\n');
    if (pem.isNotEmpty) {
      _setConfig(['pki', 'ca'], pem);
    }
  }

  String get staticMapNetwork => _getConfigString(['static_map', 'network']) ?? 'ip4';
  int get lhDuration => _getConfigInt(['lighthouse', 'interval']) ?? 0;

  List<UnsafeRoute> get unsafeRoutes {
    final routes = _getConfig<List<dynamic>>(['tun', 'unsafe_routes']);
    if (routes == null) return [];
    return routes.map((r) => UnsafeRoute.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  List<String> get dnsResolvers {
    final resolvers = _getConfig<List<dynamic>>(['mobile_nebula', 'dns_resolvers']);
    if (resolvers == null) return [];
    return resolvers.map((r) => r.toString()).toList();
  }

  Map<String, StaticHost> get staticHostmap {
    final shm = _getConfig<Map<String, dynamic>>(['static_host_map']) ?? {};
    final lhHosts = _getConfig<List<dynamic>>(['lighthouse', 'hosts']) ?? [];
    final lhSet = lhHosts.map((h) => h.toString()).toSet();

    Map<String, StaticHost> result = {};
    shm.forEach((vpnIp, rawDests) {
      List<String> dests = [];
      if (rawDests is List) {
        dests = rawDests.map((d) => d.toString()).toList();
      }
      result[vpnIp] = StaticHost.fromRawConfig(destinations: dests, lighthouse: lhSet.contains(vpnIp));
    });

    // Add any lighthouse hosts not in the static host map
    for (var lh in lhSet) {
      if (!result.containsKey(lh)) {
        result[lh] = StaticHost.fromRawConfig(destinations: [], lighthouse: true);
      }
    }

    return result;
  }

  // Convenience setters for UI — write into rawConfig
  set port(int value) => _setConfig(['listen', 'port'], value);
  set mtu(int value) => _setConfig(['tun', 'mtu'], value);
  set cipher(String value) => _setConfig(['cipher'], value);
  set logVerbosity(String value) => _setConfig(['logging', 'level'], value);
  set staticMapNetwork(String value) => _setConfig(['static_map', 'network'], value);
  set lhDuration(int value) => _setConfig(['lighthouse', 'interval'], value);

  set unsafeRoutes(List<UnsafeRoute> routes) {
    _setConfig(['tun', 'unsafe_routes'], routes.map((r) => r.toJson()).toList());
  }

  set dnsResolvers(List<String> resolvers) {
    _setConfig(['mobile_nebula', 'dns_resolvers'], resolvers);
  }

  List<String> get matchDomains {
    final domains = _getConfig<List<dynamic>>(['mobile_nebula', 'match_domains']);
    if (domains == null) return [];
    return domains.map((d) => d.toString()).toList();
  }

  set matchDomains(List<String> domains) {
    _setConfig(['mobile_nebula', 'match_domains'], domains);
  }

  List<FirewallRule> get inboundFirewallRules {
    final rules = _getConfig<List<dynamic>>(['firewall', 'inbound']);
    if (rules == null) return [];
    return rules.map((r) => FirewallRule.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  set inboundFirewallRules(List<FirewallRule> rules) {
    _setConfig(['firewall', 'inbound'], rules.map((r) => r.toJson()).toList());
  }

  List<FirewallRule> get outboundFirewallRules {
    final rules = _getConfig<List<dynamic>>(['firewall', 'outbound']);
    if (rules == null) return [];
    return rules.map((r) => FirewallRule.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  set outboundFirewallRules(List<FirewallRule> rules) {
    _setConfig(['firewall', 'outbound'], rules.map((r) => r.toJson()).toList());
  }

  set staticHostmap(Map<String, StaticHost> hostmap) {
    Map<String, List<String>> shm = {};
    List<String> lhHosts = [];

    hostmap.forEach((vpnIp, host) {
      shm[vpnIp] = host.destinations.map((d) => d.toString()).toList();
      if (host.lighthouse) {
        lhHosts.add(vpnIp);
      }
    });

    _setConfig(['static_host_map'], shm);
    _setConfig(['lighthouse', 'hosts'], lhHosts);
  }

  // Helpers for reading/writing nested rawConfig values
  T? _getConfig<T>(List<String> path) {
    dynamic current = rawConfig;
    for (var key in path) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current is T ? current : null;
  }

  int? _getConfigInt(List<String> path) {
    final val = _getConfig<dynamic>(path);
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  String? _getConfigString(List<String> path) {
    final val = _getConfig<dynamic>(path);
    return val?.toString();
  }

  void _setConfig(List<String> path, dynamic value) {
    if (path.isEmpty) return;

    Map<String, dynamic> current = rawConfig;
    for (var i = 0; i < path.length - 1; i++) {
      if (!current.containsKey(path[i]) || current[path[i]] is! Map<String, dynamic>) {
        current[path[i]] = <String, dynamic>{};
      }
      current = current[path[i]] as Map<String, dynamic>;
    }
    current[path.last] = value;
  }

  Future<void> save() async {
    try {
      var raw = jsonEncode(this);
      await platform.invokeMethod("saveSite", raw);
    } on PlatformException catch (err) {
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

/// Recursively converts a YamlMap/YamlList to plain Dart Map/List.
Map<String, dynamic> _yamlToMap(YamlMap yaml) {
  Map<String, dynamic> result = {};
  yaml.forEach((key, value) {
    result[key.toString()] = _yamlValueToDart(value);
  });
  return result;
}

dynamic _yamlValueToDart(dynamic value) {
  if (value is YamlMap) {
    return _yamlToMap(value);
  } else if (value is YamlList) {
    return value.map((v) => _yamlValueToDart(v)).toList();
  } else {
    return value;
  }
}
