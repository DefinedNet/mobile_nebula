import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mobile_nebula/models/HostInfo.dart';
import 'package:mobile_nebula/models/UnsafeRoute.dart';
import 'package:uuid/uuid.dart';

import 'Certificate.dart';
import 'StaticHosts.dart';

var uuid = Uuid();

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
  }) {
    this.id = id ?? uuid.v4();
    this.staticHostmap = staticHostmap ?? {};
    this.ca = ca ?? [];
    this.errors = errors ?? [];
    this.unsafeRoutes = unsafeRoutes ?? [];

    _updates = EventChannel('net.defined.nebula/${this.id}');
    _updateSubscription = _updates.receiveBroadcastStream().listen(
      (d) {
        try {
          _updateFromJson(d);
          _change.add(null);
        } catch (err) {
          //TODO: handle the error
          print(err);
        }
      },
      onError: (err) {
        _updateFromJson(err.details);
        var error = err as PlatformException;
        _change.addError(error.message ?? 'An unexpected error occurred');
      },
    );
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
    );
  }

  _updateFromJson(String json) {
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
  }

  static _fromJson(Map<String, dynamic> json) {
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
    };
  }

  save() async {
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

  start() async {
    try {
      await platform.invokeMethod("startSite", <String, String>{"id": id});
    } on PlatformException catch (err) {
      throw err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  stop() async {
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
