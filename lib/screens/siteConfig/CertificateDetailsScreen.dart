import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:mobile_nebula/components/SpecialSelectableText.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/services/utils.dart';

/// Displays the details of a CertificateInfo object. Respects incomplete objects (missing validity or rawCert)
class CertificateDetailsScreen extends StatefulWidget {
  const CertificateDetailsScreen({Key key, this.certificate, this.onDelete}) : super(key: key);

  final CertificateInfo certificate;
  final Function onDelete;

  @override
  _CertificateDetailsScreenState createState() => _CertificateDetailsScreenState();
}

class _CertificateDetailsScreenState extends State<CertificateDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return SimplePage(
      title: 'Certificate Details',
      child: Column(children: [
        _buildID(),
        _buildFilters(),
        _buildValid(),
        _buildAdvanced(),
        _buildDelete(),
      ]),
    );
  }

  Widget _buildID() {
    return ConfigSection(children: <Widget>[
      ConfigItem(label: Text('Name'), content: SpecialSelectableText(widget.certificate.cert.details.name)),
      ConfigItem(
          label: Text('Type'),
          content: Text(widget.certificate.cert.details.isCa ? 'CA certificate' : 'Client certificate')),
    ]);
  }

  Widget _buildValid() {
    var valid = Text('yes');
    if (widget.certificate.validity != null && !widget.certificate.validity.valid) {
      valid = Text(widget.certificate.validity.valid ? 'yes' : widget.certificate.validity.reason,
          style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)));
    }
    return ConfigSection(
      label: 'VALIDITY',
      children: <Widget>[
        ConfigItem(label: Text('Valid?'), content: valid),
        ConfigItem(
            label: Text('Created'),
            content: SpecialSelectableText(widget.certificate.cert.details.notBefore.toLocal().toString())),
        ConfigItem(
            label: Text('Expires'),
            content: SpecialSelectableText(widget.certificate.cert.details.notAfter.toLocal().toString())),
      ],
    );
  }

  Widget _buildFilters() {
    List<Widget> items = [];
    if (widget.certificate.cert.details.groups.length > 0) {
      items.add(ConfigItem(
          label: Text('Groups'), content: SpecialSelectableText(widget.certificate.cert.details.groups.join(', '))));
    }

    if (widget.certificate.cert.details.ips.length > 0) {
      items
          .add(ConfigItem(label: Text('IPs'), content: SpecialSelectableText(widget.certificate.cert.details.ips.join(', '))));
    }

    if (widget.certificate.cert.details.subnets.length > 0) {
      items.add(ConfigItem(
          label: Text('Subnets'), content: SpecialSelectableText(widget.certificate.cert.details.subnets.join(', '))));
    }

    return items.length > 0
        ? ConfigSection(label: widget.certificate.cert.details.isCa ? 'FILTERS' : 'DETAILS', children: items)
        : Container();
  }

  Widget _buildAdvanced() {
    return ConfigSection(
      children: <Widget>[
        ConfigItem(
            label: Text('Fingerprint'),
            content: SpecialSelectableText(widget.certificate.cert.fingerprint,
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
            crossAxisAlignment: CrossAxisAlignment.start),
        ConfigItem(
            label: Text('Public Key'),
            content: SpecialSelectableText(widget.certificate.cert.details.publicKey,
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
            crossAxisAlignment: CrossAxisAlignment.start),
        widget.certificate.rawCert != null
            ? ConfigItem(
                label: Text('PEM Format'),
                content: SpecialSelectableText(widget.certificate.rawCert,
                    style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
                crossAxisAlignment: CrossAxisAlignment.start)
            : Container(),
      ],
    );
  }

  Widget _buildDelete() {
    if (widget.onDelete == null) {
      return Container();
    }

    var title = widget.certificate.cert.details.isCa ? 'Delete CA?' : 'Delete cert?';

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
