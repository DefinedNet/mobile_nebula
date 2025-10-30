import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/DangerButton.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/screens/siteConfig/AddCertificateScreen.dart';
import 'package:mobile_nebula/services/utils.dart';

/// Displays the details of a CertificateInfo object. Respects incomplete objects (missing validity or rawCert)
class CertificateDetailsScreen extends StatefulWidget {
  const CertificateDetailsScreen({
    super.key,
    required this.certInfo,
    this.onDelete,
    this.onSave,
    this.onReplace,
    this.pubKey,
    this.privKey,
    required this.supportsQRScanning,
  });

  final CertificateInfo certInfo;

  // onDelete is used to remove a CA cert
  final Function? onDelete;

  // onSave is used to install a new certificate
  final Function? onSave;

  // onReplace is used to install a new certificate over top of the old one
  final ValueChanged<CertificateResult>? onReplace;

  // pubKey and privKey should be set if onReplace is not null.
  final String? pubKey;
  final String? privKey;

  final bool supportsQRScanning;

  @override
  _CertificateDetailsScreenState createState() => _CertificateDetailsScreenState();
}

class _CertificateDetailsScreenState extends State<CertificateDetailsScreen> {
  bool changed = false;
  CertificateResult? certResult;
  late CertificateInfo certInfo;
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
          widget.onSave!();
        } else if (widget.onReplace != null) {
          Navigator.pop(context);
          widget.onReplace!(certResult!);
        }
      },
      hideSave: widget.onSave == null && widget.onReplace == null,
      child: Column(
        children: [_buildID(), _buildFilters(), _buildValid(), _buildAdvanced(), _buildReplace(), _buildDelete()],
      ),
    );
  }

  Widget _buildID() {
    return ConfigSection(
      children: <Widget>[
        ConfigItem(label: Text('Name'), content: SelectableText(certInfo.cert.details.name)),
        ConfigItem(
          label: Text('Type'),
          content: Text(certInfo.cert.details.isCa ? 'CA certificate' : 'Client certificate'),
        ),
      ],
    );
  }

  Widget _buildValid() {
    var valid = Text('yes');
    if (certInfo.validity != null && !certInfo.validity!.valid) {
      valid = Text(
        certInfo.validity!.valid ? 'yes' : certInfo.validity!.reason,
        style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
      );
    }
    return ConfigSection(
      label: 'VALIDITY',
      children: <Widget>[
        ConfigItem(label: Text('Valid?'), content: valid),
        ConfigItem(
          label: Text('Created'),
          content: SelectableText(certInfo.cert.details.notBefore.toLocal().toString()),
        ),
        ConfigItem(
          label: Text('Expires'),
          content: SelectableText(certInfo.cert.details.notAfter.toLocal().toString()),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    List<Widget> items = [];
    if (certInfo.cert.details.groups.isNotEmpty) {
      items.add(ConfigItem(label: Text('Groups'), content: SelectableText(certInfo.cert.details.groups.join(', '))));
    }

    if (certInfo.cert.details.networks.isNotEmpty) {
      items.add(
        ConfigItem(label: Text('Networks'), content: SelectableText(certInfo.cert.details.networks.join(', '))),
      );
    }

    if (certInfo.cert.details.unsafeNetworks.isNotEmpty) {
      items.add(
        ConfigItem(
          label: Text('Unsafe Networks'),
          content: SelectableText(certInfo.cert.details.unsafeNetworks.join(', ')),
        ),
      );
    }

    return items.isNotEmpty
        ? ConfigSection(label: certInfo.cert.details.isCa ? 'FILTERS' : 'DETAILS', children: items)
        : Container();
  }

  Widget _buildAdvanced() {
    return ConfigSection(
      children: <Widget>[
        ConfigItem(
          label: Text('Fingerprint'),
          content: SelectableText(certInfo.cert.fingerprint, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
        ConfigItem(
          label: Text('Public Key'),
          content: SelectableText(
            certInfo.cert.details.publicKey,
            style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14),
          ),
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
        certInfo.rawCert != null
            ? ConfigItem(
              label: Text('PEM Format'),
              content: SelectableText(certInfo.rawCert!, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
              crossAxisAlignment: CrossAxisAlignment.start,
            )
            : Container(),
      ],
    );
  }

  Widget _buildReplace() {
    if (widget.onReplace == null || widget.pubKey == null || widget.privKey == null) {
      return Container();
    }

    return Padding(
      padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
      child: SizedBox(
        width: double.infinity,
        child: DangerButton(
          child: Text('Replace certificate'),
          onPressed: () {
            Utils.openPage(context, (context) {
              return AddCertificateScreen(
                onReplace: (result) {
                  setState(() {
                    changed = true;
                    certResult = result;
                    certInfo = result.certInfo;
                  });
                  // Slam the page back to the top
                  controller.animateTo(0, duration: const Duration(milliseconds: 10), curve: Curves.linearToEaseOut);
                },
                pubKey: widget.pubKey!,
                privKey: widget.privKey!,
                supportsQRScanning: widget.supportsQRScanning,
              );
            });
          },
        ),
      ),
    );
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
        child: DangerButton(
          child: Text('Delete'),
          onPressed:
              () => Utils.confirmDelete(context, title, () async {
                Navigator.pop(context);
                widget.onDelete!();
              }),
        ),
      ),
    );
  }
}
