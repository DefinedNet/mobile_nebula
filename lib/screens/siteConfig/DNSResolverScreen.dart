import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/IPFormField.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/services/utils.dart';

class DNSResolverScreen extends StatefulWidget {
  const DNSResolverScreen({Key? key, required this.dnsResolver, required this.onDelete, required this.onSave}) : super(key: key);

  final String dnsResolver;
  final ValueChanged<String> onSave;
  final Function onDelete;

  @override
  _DNSResolverScreenState createState() => _DNSResolverScreenState();
}

class _DNSResolverScreenState extends State<DNSResolverScreen> {
  late String dnsResolver;
  bool changed = false;

  FocusNode dnsResolverFocus = FocusNode();

  @override
  void initState() {
    dnsResolver = widget.dnsResolver;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
        title: widget.onDelete == null ? 'New DNS Resolver' : 'Edit DNS Resolver',
        changed: changed,
        onSave: _onSave,
        child: Column(children: [
          ConfigSection(children: <Widget>[
            ConfigItem(
                label: Text('Address'),
                content: IPFormField(
                    initialValue: dnsResolver,
                    ipOnly: true,
                    textInputAction: TextInputAction.next,
                    focusNode: dnsResolverFocus,
                    onSaved: (v) {
                      dnsResolver = v.toString();
                    })),
          ]),
          widget.onDelete != null
              ? Padding(
                  padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
                  child: SizedBox(
                      width: double.infinity,
                      child: PlatformElevatedButton(
                        child: Text('Delete'),
                        color: CupertinoColors.systemRed.resolveFrom(context),
                        onPressed: () => Utils.confirmDelete(context, 'Delete DNS Resolver?', () {
                          Navigator.of(context).pop();
                          widget.onDelete();
                        }),
                      )))
              : Container()
        ]));
  }

  _onSave() {
    Navigator.pop(context);
    if (widget.onSave != null) {
      widget.onSave(dnsResolver);
    }
  }
}
