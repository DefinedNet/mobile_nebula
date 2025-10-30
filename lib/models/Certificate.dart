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
      fingerprint = "DEBUG",
      signature = "DEBUG";

  Certificate.fromJson(Map<String, dynamic> json)
    : version = json["version"],
      name = json['name'],
      networks = List<String>.from(json['networks']),
      unsafeNetworks = List<String>.from(json['unsafeNetworks']),
      groups = List<String>.from(json['groups']),
      isCa = json['isCa'],
      notBefore = DateTime.parse(json['notBefore']),
      notAfter = DateTime.parse(json['notAfter']),
      issuer = json['issuer'],
      publicKey = json['publicKey'],
      fingerprint = json['fingerprint'],
      signature = json['signature'];
}

class CertificateValidity {
  bool valid;
  String reason;

  CertificateValidity.debug() : valid = true, reason = "";

  CertificateValidity.fromJson(Map<String, dynamic> json) : valid = json['Valid'], reason = json['Reason'];
}
