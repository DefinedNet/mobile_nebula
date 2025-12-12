class CertificateInfo {
  Certificate cert;
  String? rawCert;
  CertificateValidity? validity;

  CertificateInfo.debug({this.rawCert = ""}) : cert = Certificate.debug(), validity = CertificateValidity.debug();

  CertificateInfo.fromJson(Map<String, dynamic> json)
    : cert = Certificate.fromJson(json['Cert']),
      rawCert = json['RawCert'],
      validity = CertificateValidity.fromJson(json['Validity']);

  CertificateInfo({required this.cert, this.rawCert, this.validity});

  static List<CertificateInfo> fromJsonList(List<dynamic> list) {
    return list.map((v) => CertificateInfo.fromJson(v)).toList();
  }
}

class Certificate {
  int version;
  String name;
  List<String> networks;
  List<String> unsafeNetworks;
  List<String> groups;
  bool isCa;
  DateTime notBefore;
  DateTime notAfter;
  String issuer;
  String publicKey;
  String curve;
  String fingerprint;
  String signature;

  Certificate.debug()
    : version = 2,
      name = "DEBUG",
      networks = [],
      unsafeNetworks = [],
      groups = [],
      isCa = false,
      notBefore = DateTime.now(),
      notAfter = DateTime.now(),
      issuer = "DEBUG",
      publicKey = "",
      curve = "",
      fingerprint = "DEBUG",
      signature = "DEBUG";

  factory Certificate.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> details = json;
    String publicKey;
    String curve;
    if (json.containsKey("details")) {
      details = json["details"];
      //TODO: currently swift and kotlin flatten the certificate structure but
      // nebula outputs cert json in the nested format
      switch (json["version"]) {
        case 1:
          // In V1 the public key was under details
          publicKey = details["publicKey"];
          curve = details["curve"];
          break;
        case 2:
          // In V2 the public key moved to the top level
          publicKey = json["publicKey"];
          curve = json["curve"];
          break;
        default:
          throw Exception('Unknown certificate version');
      }
    } else {
      // This is a flattened certificate format, publicKey is at the top
      publicKey = json["publicKey"];
      curve = json["curve"];
    }

    return Certificate(
      json["version"],
      details["name"],
      List<String>.from(details['networks'] ?? []),
      List<String>.from(details['unsafeNetworks'] ?? []),
      List<String>.from(details['groups']),
      details['isCa'],
      DateTime.parse(details['notBefore']),
      DateTime.parse(details['notAfter']),
      details['issuer'],
      publicKey,
      curve,
      json['fingerprint'],
      json['signature'],
    );
  }

  Certificate(
    this.version,
    this.name,
    this.networks,
    this.unsafeNetworks,
    this.groups,
    this.isCa,
    this.notBefore,
    this.notAfter,
    this.issuer,
    this.publicKey,
    this.curve,
    this.fingerprint,
    this.signature,
  );
}

class CertificateValidity {
  bool valid;
  String reason;

  CertificateValidity.debug() : valid = true, reason = "";

  CertificateValidity.fromJson(Map<String, dynamic> json) : valid = json['Valid'], reason = json['Reason'];
}
