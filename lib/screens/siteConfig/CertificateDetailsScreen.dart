import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/screens/siteConfig/AddCertificateScreen.dart';
import 'package:mobile_nebula/services/utils.dart';

/// Displays the details of a CertificateInfo object. Respects incomplete objects (missing validity or rawCert)
class CertificateDetailsScreen extends StatefulWidget {
  const CertificateDetailsScreen({Key key, this.certInfo, this.onDelete, this.onSave, this.onReplace})
      : super(key: key);

  final CertificateInfo certInfo;

  // onDelete is used to remove a CA cert
  final Function onDelete;

  // onSave is used to install a new certificate
  final Function onSave;

  // onReplace is used to install a new certificate over top of the old one
  final ValueChanged<CertificateResult> onReplace;

  @override
  _CertificateDetailsScreenState createState() => _CertificateDetailsScreenState();
}

class _CertificateDetailsScreenState extends State<CertificateDetailsScreen> {
  bool changed = false;
  CertificateResult certResult;
  CertificateInfo certInfo;
  ScrollController controller = ScrollController();

  @override
  void initState() {
    certInfo = widget.certInfo;
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Certificate Details',
      scrollController: controller,
      changed: widget.onSave != null || changed,
      onSave: () {
        if (widget.onSave != null) {
          Navigator.pop(context);
          widget.onSave();
        } else if (widget.onReplace != null) {
          Navigator.pop(context);
          widget.onReplace(certResult);
        }
      },
      hideSave: widget.onSave == null && widget.onReplace == null,
      child: Column(children: [
        _buildID(),
        _buildFilters(),
        _buildValid(),
        _buildAdvanced(),
        _buildReplace(),
        _buildDelete(),
      ]),
    );
  }

  Widget _buildID() {
    return ConfigSection(children: <Widget>[
      ConfigItem(label: Text('Name'), content: SelectableText(certInfo.cert.details.name)),
      ConfigItem(
          label: Text('Type'), content: Text(certInfo.cert.details.isCa ? 'CA certificate' : 'Client certificate')),
    ]);
  }

  Widget _buildValid() {
    var valid = Text('yes');
    if (certInfo.validity != null && !certInfo.validity.valid) {
      valid = Text(certInfo.validity.valid ? 'yes' : certInfo.validity.reason,
          style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)));
    }
    return ConfigSection(
      label: 'VALIDITY',
      children: <Widget>[
        ConfigItem(label: Text('Valid?'), content: valid),
        ConfigItem(
            label: Text('Created'),
            content: SelectableText(certInfo.cert.details.notBefore.toLocal().toString())),
        ConfigItem(
            label: Text('Expires'),
            content: SelectableText(certInfo.cert.details.notAfter.toLocal().toString())),
      ],
    );
  }

  Widget _buildFilters() {
    List<Widget> items = [];
    if (certInfo.cert.details.groups.length > 0) {
      items.add(
          ConfigItem(label: Text('Groups'), content: SelectableText(certInfo.cert.details.groups.join(', '))));
    }

    if (certInfo.cert.details.ips.length > 0) {
      items.add(ConfigItem(label: Text('IPs'), content: SelectableText(certInfo.cert.details.ips.join(', '))));
    }

    if (certInfo.cert.details.subnets.length > 0) {
      items.add(
          ConfigItem(label: Text('Subnets'), content: SelectableText(certInfo.cert.details.subnets.join(', '))));
    }

    return items.length > 0
        ? ConfigSection(label: certInfo.cert.details.isCa ? 'FILTERS' : 'DETAILS', children: items)
        : Container();
  }

  Widget _buildAdvanced() {
    return ConfigSection(
      children: <Widget>[
        ConfigItem(
            label: Text('Fingerprint'),
            content: SelectableText(certInfo.cert.fingerprint,
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
            crossAxisAlignment: CrossAxisAlignment.start),
        ConfigItem(
            label: Text('Public Key'),
            content: SelectableText(certInfo.cert.details.publicKey,
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
            crossAxisAlignment: CrossAxisAlignment.start),
        certInfo.rawCert != null
            ? ConfigItem(
                label: Text('PEM Format'),
                content:
                SelectableText(certInfo.rawCert, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
                crossAxisAlignment: CrossAxisAlignment.start)
            : Container(),
      ],
    );
  }

  Widget _buildReplace() {
    if (widget.onReplace == null) {
      return Container();
    }

    return Padding(
        padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
        child: SizedBox(
            width: double.infinity,
            child: PlatformButton(
                child: Text('Replace certificate'),
                color: CupertinoColors.systemRed.resolveFrom(context),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return AddCertificateScreen(onReplace: (result) {
                      setState(() {
                        changed = true;
                        certResult = result;
                        certInfo = certResult.certInfo;
                      });
                      // Slam the page back to the top
                      controller.animateTo(0,
                          duration: const Duration(milliseconds: 10), curve: Curves.linearToEaseOut);
                    });
                  });
                })));
  }

  Widget _buildDelete() {
    if (widget.onDelete == null) {
      return Container();
    }

    var title = certInfo.cert.details.isCa ? 'Delete CA?' : 'Delete cert?';

    return Padding(
        padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
        child: SizedBox(
            width: double.infinity,
            child: PlatformButton(
                child: Text('Delete'),
                color: CupertinoColors.systemRed.resolveFrom(context),
                onPressed: () => Utils.confirmDelete(context, title, () async {
                      Navigator.pop(context);
                      widget.onDelete();
                    }))));
  }
}
