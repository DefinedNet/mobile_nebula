class CertificateInfo {
  Certificate cert;
  String rawCert;
  CertificateValidity validity;

  CertificateInfo.debug({this.rawCert = ""})
      : this.cert = Certificate.debug(),
        this.validity = CertificateValidity.debug();

  CertificateInfo.fromJson(Map<String, dynamic> json)
      : cert = Certificate.fromJson(json['Cert']),
        rawCert = json['RawCert'],
        validity = CertificateValidity.fromJson(json['Validity']);

  CertificateInfo({this.cert, this.rawCert, this.validity});

  static List<CertificateInfo> fromJsonList(List<dynamic> list) {
    return list.map((v) => CertificateInfo.fromJson(v));
  }
}

class Certificate {
  CertificateDetails details;
  String fingerprint;
  String signature;

  Certificate.debug()
      : this.details = CertificateDetails.debug(),
        this.fingerprint = "DEBUG",
        this.signature = "DEBUG";

  Certificate.fromJson(Map<String, dynamic> json)
      : details = CertificateDetails.fromJson(json['details']),
        fingerprint = json['fingerprint'],
        signature = json['signature'];
}

class CertificateDetails {
  String name;
  DateTime notBefore;
  DateTime notAfter;
  String publicKey;
  List<String> groups;
  List<String> ips;
  List<String> subnets;
  bool isCa;
  String issuer;

  CertificateDetails.debug()
      : this.name = "DEBUG",
        notBefore = DateTime.now(),
        notAfter = DateTime.now(),
        publicKey = "",
        groups = [],
        ips = [],
        subnets = [],
        isCa = false,
        issuer = "DEBUG";

  CertificateDetails.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        notBefore = DateTime.tryParse(json['notBefore']),
        notAfter = DateTime.tryParse(json['notAfter']),
        publicKey = json['publicKey'],
        groups = List<String>.from(json['groups']),
        ips = List<String>.from(json['ips']),
        subnets = List<String>.from(json['subnets']),
        isCa = json['isCa'],
        issuer = json['issuer'];
}

class CertificateValidity {
  bool valid;
  String reason;

  CertificateValidity.debug()
      : this.valid = true,
        this.reason = "";

  CertificateValidity.fromJson(Map<String, dynamic> json)
      : valid = json['Valid'],
        reason = json['Reason'];
}
