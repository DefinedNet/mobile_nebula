import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigButtonItem.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Hostmap.dart';
import 'package:mobile_nebula/models/IPAndPort.dart';
import 'package:mobile_nebula/models/StaticHosts.dart';
import 'package:mobile_nebula/screens/siteConfig/StaticHostmapScreen.dart';
import 'package:mobile_nebula/services/utils.dart';

//TODO: wire up the focus nodes, add a done/next/prev to the keyboard

class _Hostmap {
  final FocusNode focusNode;
  String nebulaIp;
  List<IPAndPort> destinations;
  bool lighthouse;

  _Hostmap({
    required this.focusNode,
    required this.nebulaIp,
    required this.destinations,
    required this.lighthouse,
  });
}

class StaticHostsScreen extends StatefulWidget {
  const StaticHostsScreen({
    Key? key,
    required this.hostmap,
    required this.onSave,
  }) : super(key: key);

  final Map<String, StaticHost> hostmap;
  final ValueChanged<Map<String, StaticHost>> onSave;

  @override
  _StaticHostsScreenState createState() => _StaticHostsScreenState();
}

class _StaticHostsScreenState extends State<StaticHostsScreen> {
  Map<Key, _Hostmap> _hostmap = {};
  bool changed = false;

  @override
  void initState() {
    widget.hostmap.forEach((key, map) {
      _hostmap[UniqueKey()] =
          _Hostmap(focusNode: FocusNode(), nebulaIp: key, destinations: map.destinations, lighthouse: map.lighthouse);
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
        title: 'Static Hosts',
        changed: changed,
        onSave: _onSave,
        child: ConfigSection(
          children: _buildHosts(),
        ));
  }

  _onSave() {
    Navigator.pop(context);
    Map<String, StaticHost> map = {};
    _hostmap.forEach((_, host) {
      map[host.nebulaIp] = StaticHost(destinations: host.destinations, lighthouse: host.lighthouse);
    });

    widget.onSave(map);
  }

  List<Widget> _buildHosts() {
    final double ipWidth = Utils.textSize("000.000.000.000", CupertinoTheme.of(context).textTheme.textStyle).width + 32;
    List<Widget> items = [];
    _hostmap.forEach((key, host) {
      items.add(ConfigPageItem(
        label: Row(children: <Widget>[
          Padding(
              child: Icon(host.lighthouse ? Icons.lightbulb_outline : Icons.computer,
                  color: CupertinoColors.placeholderText.resolveFrom(context)),
              padding: EdgeInsets.only(right: 10)),
          Text(host.nebulaIp),
        ]),
        labelWidth: ipWidth,
        content: Text(host.destinations.length.toString() + ' items', textAlign: TextAlign.end),
        onPressed: () {
          Utils.openPage(context, (context) {
            return StaticHostmapScreen(
                nebulaIp: host.nebulaIp,
                destinations: host.destinations,
                lighthouse: host.lighthouse,
                onSave: (map) {
                  setState(() {
                    changed = true;
                    host.nebulaIp = map.nebulaIp;
                    host.destinations = map.destinations;
                    host.lighthouse = map.lighthouse;
                  });
                },
                onDelete: () {
                  setState(() {
                    changed = true;
                    _hostmap.remove(key);
                  });
                });
          });
        },
      ));
    });

    items.add(ConfigButtonItem(
      content: Text('Add a new entry'),
      onPressed: () {
        Utils.openPage(context, (context) {
          return StaticHostmapScreen(onSave: (map) {
            setState(() {
              changed = true;
              _addHostmap(map);
            });
          });
        });
      },
    ));

    return items;
  }

  _addHostmap(Hostmap map) {
    _hostmap[UniqueKey()] = (_Hostmap(
        focusNode: FocusNode(), nebulaIp: map.nebulaIp, destinations: map.destinations, lighthouse: map.lighthouse));
  }

  @override
  void dispose() {
    _hostmap.forEach((key, host) {
      host.focusNode.dispose();
    });

    super.dispose();
  }
}
