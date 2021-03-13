import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mobile_nebula/models/HostInfo.dart';
import 'package:mobile_nebula/models/UnsafeRoute.dart';
import 'package:mobile_nebula/models/IPAndPort.dart';
import 'package:uuid/uuid.dart';
import 'Certificate.dart';
import 'StaticHosts.dart';

var uuid = Uuid();

class Site {
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');
  EventChannel _updates;

  /// Signals that something about this site has changed. onError is called with an error string if there was an error
  StreamController _change = StreamController.broadcast();

  // Identifiers
  String name;
  String id;

  // static_host_map
  Map<String, StaticHost> staticHostmap;
  List<UnsafeRoute> unsafeRoutes;
  List<String> dnsResolvers;

  // pki fields
  List<CertificateInfo> ca;
  CertificateInfo cert;
  String key;

  // lighthouse options
  int lhDuration; // in seconds

  // listen settings
  int port;
  int mtu;

  String cipher;
  int sortKey;
  bool connected;
  String status;
  String logFile;
  String logVerbosity;

  // A list of errors encountered while loading the site
  List<String> errors;

  Site(
      {this.name,
      id,
      staticHostmap,
      ca,
      this.cert,
      this.lhDuration = 0,
      this.port = 0,
      this.cipher = "aes",
      this.sortKey,
      this.mtu = 1300,
      this.connected,
      this.status,
      this.logFile,
      this.logVerbosity = 'info',
      errors,
      unsafeRoutes,
      dnsResolvers})
      : staticHostmap = staticHostmap ?? {},
        unsafeRoutes = unsafeRoutes ?? [],
        dnsResolvers = dnsResolvers ?? [],
        errors = errors ?? [],
        ca = ca ?? [],
        id = id ?? uuid.v4();

  Site.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    id = json['id'];

    Map<String, dynamic> rawHostmap = json['staticHostmap'];
    staticHostmap = {};
    rawHostmap.forEach((key, val) {
      staticHostmap[key] = StaticHost.fromJson(val);
    });

    List<dynamic> rawUnsafeRoutes = json['unsafeRoutes'];
    unsafeRoutes = [];
    if (rawUnsafeRoutes != null) {
      rawUnsafeRoutes.forEach((val) {
        unsafeRoutes.add(UnsafeRoute.fromJson(val));
      });
    }

    List<dynamic> rawDNSResolvers = json['dnsResolvers'];
    dnsResolvers = [];
    (rawDNSResolvers ?? []).forEach((val) {
      dnsResolvers.add(val);
    });

    List<dynamic> rawCA = json['ca'];
    ca = [];
    rawCA.forEach((val) {
      ca.add(CertificateInfo.fromJson(val));
    });

    if (json['cert'] != null) {
      cert = CertificateInfo.fromJson(json['cert']);
    }

    lhDuration = json['lhDuration'];
    port = json['port'];
    mtu = json['mtu'];
    cipher = json['cipher'];
    sortKey = json['sortKey'];
    logFile = json['logFile'];
    logVerbosity = json['logVerbosity'];
    connected = json['connected'] ?? false;
    status = json['status'] ?? "";

    errors = [];
    List<dynamic> rawErrors = json["errors"];
    rawErrors.forEach((error) {
      errors.add(error);
    });

    _updates = EventChannel('net.defined.nebula/$id');
    _updates.receiveBroadcastStream().listen((d) {
      try {
        this.status = d['status'];
        this.connected = d['connected'];
        _change.add(null);
      } catch (err) {
        //TODO: handle the error
        print(err);
      }
    }, onError: (err) {
      var error = err as PlatformException;
      this.status = error.details['status'];
      this.connected = error.details['connected'];
      _change.addError(error.message);
    });
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
      'dnsResolvers': dnsResolvers,
      'ca': ca?.map((cert) {
            return cert.rawCert;
          })?.join('\n') ??
          "",
      'cert': cert?.rawCert,
      'key': key,
      'lhDuration': lhDuration,
      'port': port,
      'mtu': mtu,
      'cipher': cipher,
      'sortKey': sortKey,
      'logVerbosity': logVerbosity,
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
      //TODO: fix this message
      throw err.details ?? err.message ?? err.toString();
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
      var ret = await platform.invokeMethod("active.listHostmap", <String, String>{"id": id});
      if (ret == null) {
        return [];
      }

      List<dynamic> f = jsonDecode(ret);
      List<HostInfo> hosts = [];
      f.forEach((v) {
        hosts.add(HostInfo.fromJson(v));
      });

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
      if (ret == null) {
        return [];
      }

      List<dynamic> f = jsonDecode(ret);
      List<HostInfo> hosts = [];
      f.forEach((v) {
        hosts.add(HostInfo.fromJson(v));
      });

      return hosts;

    } on PlatformException catch (err) {
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  Future<Map<String, List<HostInfo>>> listAllHostmaps() async {
    try {
      var res = await Future.wait([this.listHostmap(), this.listPendingHostmap()]);
      return {"active": res[0], "pending": res[1]};

    } on PlatformException catch (err) {
      throw err.details ?? err.message ?? err.toString();
    } catch (err) {
      throw err.toString();
    }
  }

  void dispose() {
    _change.close();
  }

  Future<HostInfo> getHostInfo(String vpnIp, bool pending) async {
    try {
      var ret = await platform.invokeMethod("active.getHostInfo", <String, dynamic>{"id": id, "vpnIp": vpnIp, "pending": pending});
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

  Future<HostInfo> setRemoteForTunnel(String vpnIp, String addr) async {
    try {
      var ret = await platform.invokeMethod("active.setRemoteForTunnel", <String, dynamic>{"id": id, "vpnIp": vpnIp, "addr": addr});
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
