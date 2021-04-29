import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/SpecialSelectableText.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Certificate.dart';
import 'package:mobile_nebula/services/utils.dart';

//TODO: add a primary toggle if we have multiple sites

/// Displays the details of a CertificateInfo object. Respects incomplete objects (missing validity or rawCert)
class CertificateDetailsScreen extends StatefulWidget {
  const CertificateDetailsScreen(this.certInfo, {Key key, this.onDelete, this.onSave, this.newCert = false, this.choosePrimary = false}) : super(key: key);

  final CertificateInfo certInfo;
  final Function onDelete;
  final ValueChanged<bool> onSave;
  final bool newCert;
  final bool choosePrimary;

  @override
  _CertificateDetailsScreenState createState() => _CertificateDetailsScreenState();
}

class _CertificateDetailsScreenState extends State<CertificateDetailsScreen> {
  bool primary;
  bool changed = false;

  @override
  void initState() {
    primary = widget.certInfo.primary ?? false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Certificate Details',
      onSave: () {
        Navigator.pop(context);
        widget.onSave(widget.choosePrimary == true ? primary : false);
      },
      changed: widget.newCert || changed,
      child: Column(children: [
        widget.choosePrimary ? _buildPrimaryChooser() : Container(),
        _buildID(),
        _buildFilters(),
        _buildValid(),
        _buildAdvanced(),
        _buildDelete(),
      ]),
    );
  }

  Widget _buildPrimaryChooser() {
    return ConfigSection(children: <Widget>[
      ConfigItem(
          label: Text('Primary Certificate'),
          content: Container(
              alignment: Alignment.centerRight,
              child: Switch.adaptive(
                  value: primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) {
                    setState(() {
                      changed = true;
                      primary = v;
                    });
                  })),
          )]);
  }

  Widget _buildID() {
    return ConfigSection(children: <Widget>[
      ConfigItem(label: Text('Name'), content: SpecialSelectableText(widget.certInfo.cert.details.name)),
      ConfigItem(
          label: Text('Type'),
          content: Text(widget.certInfo.cert.details.isCa ? 'CA certificate' : 'Client certificate')),
    ]);
  }

  Widget _buildValid() {
    var valid = Text('yes');
    if (widget.certInfo.validity != null && !widget.certInfo.validity.valid) {
      valid = Text(widget.certInfo.validity.valid ? 'yes' : widget.certInfo.validity.reason,
          style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)));
    }
    return ConfigSection(
      label: 'VALIDITY',
      children: <Widget>[
        ConfigItem(label: Text('Valid?'), content: valid),
        ConfigItem(
            label: Text('Created'),
            content: SpecialSelectableText(widget.certInfo.cert.details.notBefore.toLocal().toString())),
        ConfigItem(
            label: Text('Expires'),
            content: SpecialSelectableText(widget.certInfo.cert.details.notAfter.toLocal().toString())),
      ],
    );
  }

  Widget _buildFilters() {
    List<Widget> items = [];
    if (widget.certInfo.cert.details.groups.length > 0) {
      items.add(ConfigItem(
          label: Text('Groups'), content: SpecialSelectableText(widget.certInfo.cert.details.groups.join(', '))));
    }

    if (widget.certInfo.cert.details.ips.length > 0) {
      items
          .add(ConfigItem(label: Text('IPs'), content: SpecialSelectableText(widget.certInfo.cert.details.ips.join(', '))));
    }

    if (widget.certInfo.cert.details.subnets.length > 0) {
      items.add(ConfigItem(
          label: Text('Subnets'), content: SpecialSelectableText(widget.certInfo.cert.details.subnets.join(', '))));
    }

    return items.length > 0
        ? ConfigSection(label: widget.certInfo.cert.details.isCa ? 'FILTERS' : 'DETAILS', children: items)
        : Container();
  }

  Widget _buildAdvanced() {
    return ConfigSection(
      children: <Widget>[
        ConfigItem(
            label: Text('Fingerprint'),
            content: SpecialSelectableText(widget.certInfo.cert.fingerprint,
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
            crossAxisAlignment: CrossAxisAlignment.start),
        ConfigItem(
            label: Text('Public Key'),
            content: SpecialSelectableText(widget.certInfo.cert.details.publicKey,
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 14)),
            crossAxisAlignment: CrossAxisAlignment.start),
        widget.certInfo.rawCert != null
            ? ConfigItem(
                label: Text('PEM Format'),
                content: SpecialSelectableText(widget.certInfo.rawCert,
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

    var title = widget.certInfo.cert.details.isCa ? 'Delete CA?' : 'Delete cert?';

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
