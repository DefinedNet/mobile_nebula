import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigButtonItem.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/models/Site.dart';
import 'package:mobile_nebula/screens/siteConfig/CertificateDetailsScreen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'AddCertificateScreen.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({Key key, this.site, this.onSave}) : super(key: key);

  final Site site;
  final ValueChanged<Site> onSave;

  @override
  _CertificatesScreenState createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  Site site;
  CertificateInfo primary;
  bool changed = false;

  @override
  void initState() {
    site = widget.site;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var items = _buildCertList();

    items.add(ConfigButtonItem(
      content: Text('Add a certificate'),
      onPressed: () {
        Utils.openPage(context, (context) {
          //TODO: thread through the primary choice
          return AddCertificateScreen(choosePrimary: true, onSave: (certInfo) {
            setState(() {
              changed = true;
              site.certInfos.add(certInfo);
              if (certInfo.primary) {
                _setPrimary(certInfo);
              }
            });
          });
        });
      },
    ));

    return FormPage(
        title: 'Certificates',
        changed: changed,
        onSave: () {
          Navigator.pop(context);
          if (widget.onSave != null) {
            widget.onSave(site);
          }
        },
        child: ConfigSection(children: items));
  }

  List<Widget> _buildCertList() {
    List<Widget> list = [];
    site.certInfos.forEach((certInfo) {
      var title = certInfo.cert.details.name;
      if (certInfo.primary ?? false) {
        title += " (primary)";
      }
      list.add(ConfigPageItem(
            content: Text(title),
            onPressed: () {
              Utils.openPage(context, (context) {
                return CertificateDetailsScreen(
                  certInfo,
                  choosePrimary: site.certInfos.length > 1,
                  onSave: (isPrimary) {
                    if (isPrimary) {
                      _setPrimary(certInfo);
                    }
                  },
                  onDelete: () {
                    setState(() {
                      changed = true;
                      site.certInfos.remove(certInfo);
                      if (primary.cert.fingerprint)
                    });
                  }
                );
              });
            },
          ));
    });

    return list;
  }

  _setPrimary(CertificateInfo certInfo) {
    // Turn every certInfo object to non primary
    site.certInfos.forEach((certInfo) {
      certInfo.primary = false;
    });

    // Flip this new primary on
    certInfo.primary = true;
    site.primaryCertInfo = certInfo;
    setState(() {});
  }
}
