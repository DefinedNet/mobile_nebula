import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigButtonItem.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/screens/siteConfig/DNSResolverScreen.dart';
import 'package:mobile_nebula/services/utils.dart';

class DNSResolversScreen extends StatefulWidget {
  const DNSResolversScreen(
      {Key? key, required this.dnsResolvers, required this.onSave})
      : super(key: key);

  final List<String> dnsResolvers;
  final ValueChanged<List<String>> onSave;

  @override
  _DNSResolversScreenState createState() => _DNSResolversScreenState();
}

class _DNSResolversScreenState extends State<DNSResolversScreen> {
  late List<String> dnsResolvers = [];
  bool changed = false;

  @override
  void initState() {
    widget.dnsResolvers.forEach((dnsResolver) {
      dnsResolvers.add(dnsResolver);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
        title: 'DNS Resolvers',
        changed: changed,
        onSave: _onSave,
        child: ConfigSection(
          children: _build(),
        ));
  }

  _onSave() {
    Navigator.pop(context);
    if (widget.onSave != null) {
      widget.onSave(dnsResolvers);
    }
  }

  List<Widget> _build() {
    List<Widget> items = [];
    for (var i=0; i<dnsResolvers.length;i++) {
      final dnsResolver = dnsResolvers[i];
      items.add(ConfigPageItem(
        label: Text("Resolver"),
        content: Text(dnsResolver, textAlign: TextAlign.end),
        onPressed: () {
          Utils.openPage(context, (context) {
            return DNSResolverScreen(
              dnsResolver: dnsResolver,
              onSave: (dnsResolver) {
                setState(() {
                  changed = true;
                  dnsResolvers[i] = dnsResolver;
                });
              },
              onDelete: () {
                setState(() {
                  changed = true;
                  dnsResolvers.removeAt(i);
                });
              },
            );
          });
        },
      ));
    }

    items.add(ConfigButtonItem(
      content: Text('Add a new DNS resolver'),
      onPressed: () {
        Utils.openPage(context, (context) {
          return DNSResolverScreen(
              dnsResolver: "",
              onSave: (dnsResolver) {
                  setState(() {
                      changed = true;
                  });
                  dnsResolvers.add(dnsResolver);
              },
              onDelete: () {},
          );
        });
      },
    ));

    return items;
  }
}
