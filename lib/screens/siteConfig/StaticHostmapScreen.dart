import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/components/DangerButton.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/IPAndPortFormField.dart';
import 'package:mobile_nebula/components/IPFormField.dart';
import 'package:mobile_nebula/components/config/ConfigButtonItem.dart';
import 'package:mobile_nebula/components/config/ConfigItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/Hostmap.dart';
import 'package:mobile_nebula/models/IPAndPort.dart';
import 'package:mobile_nebula/services/utils.dart';

class _IPAndPort {
  final FocusNode focusNode;
  IPAndPort destination;

  _IPAndPort({required this.focusNode, required this.destination});
}

class StaticHostmapScreen extends StatefulWidget {
  StaticHostmapScreen({
    Key? key,
    this.nebulaIp = '',
    destinations,
    this.lighthouse = false,
    this.onDelete,
    required this.onSave,
  })  : this.destinations = destinations ?? [],
        super(key: key);

  final List<IPAndPort> destinations;
  final String nebulaIp;
  final bool lighthouse;
  final ValueChanged<Hostmap>? onSave;
  final Function? onDelete;

  @override
  _StaticHostmapScreenState createState() => _StaticHostmapScreenState();
}

class _StaticHostmapScreenState extends State<StaticHostmapScreen> {
  late Map<Key, _IPAndPort> _destinations;
  late String _nebulaIp;
  late bool _lighthouse;
  bool changed = false;

  @override
  void initState() {
    _nebulaIp = widget.nebulaIp;
    _lighthouse = widget.lighthouse;
    _destinations = {};
    widget.destinations.forEach((dest) {
      _destinations[UniqueKey()] = _IPAndPort(focusNode: FocusNode(), destination: dest);
    });

    if (_destinations.length == 0) {
      _addDestination();
    }

    // _addDestination() above sets us to changed, set it back to false since we are at the default state
    changed = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
        title: widget.onDelete == null
            ? widget.onSave == null
                ? 'View Static Host'
                : 'New Static Host'
            : 'Edit Static Host',
        changed: changed,
        onSave: _onSave,
        child: Column(children: [
          ConfigSection(label: 'Maps a nebula ip address to multiple real world addresses', children: <Widget>[
            ConfigItem(
                label: Text('Nebula IP'),
                labelWidth: 200,
                content: widget.onSave == null
                    ? Text(_nebulaIp, textAlign: TextAlign.end)
                    : IPFormField(
                        help: "Required",
                        initialValue: _nebulaIp,
                        ipOnly: true,
                        textAlign: TextAlign.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        textInputAction: TextInputAction.next,
                        onSaved: (v) {
                          if (v != null) {
                            _nebulaIp = v;
                          }
                        })),
            ConfigItem(
              label: Text('Lighthouse'),
              labelWidth: 200,
              content: Container(
                  alignment: Alignment.centerRight,
                  child: Switch.adaptive(
                      value: _lighthouse,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: widget.onSave == null
                          ? null
                          : (v) {
                              setState(() {
                                changed = true;
                                _lighthouse = v;
                              });
                            })),
            ),
          ]),
          ConfigSection(
            label: 'List of public ips or dns names where for this host',
            children: _buildHosts(),
          ),
          widget.onDelete != null
              ? Padding(
                  padding: EdgeInsets.only(top: 50, bottom: 10, left: 10, right: 10),
                  child: SizedBox(
                      width: double.infinity,
                      child: DangerButton(
                          child: Text('Delete'),
                          onPressed: () => Utils.confirmDelete(context, 'Delete host map?', () {
                                Navigator.of(context).pop();
                                widget.onDelete!();
                              }))))
              : Container()
        ]));
  }

  _onSave() {
    Navigator.pop(context);
    if (widget.onSave != null) {
      var map = Hostmap(nebulaIp: _nebulaIp, destinations: [], lighthouse: _lighthouse);

      _destinations.forEach((_, dest) {
        map.destinations.add(dest.destination);
      });

      widget.onSave!(map);
    }
  }

  List<Widget> _buildHosts() {
    List<Widget> items = [];

    _destinations.forEach((key, dest) {
      items.add(ConfigItem(
        key: key,
        label: Align(
            alignment: Alignment.centerLeft,
            child: widget.onSave == null
                ? Container()
                : PlatformIconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.remove_circle, color: CupertinoColors.systemRed.resolveFrom(context)),
                    onPressed: () => setState(() {
                          _removeDestination(key);
                          _dismissKeyboard();
                        }))),
        labelWidth: 70,
        content: Row(children: <Widget>[
          Expanded(
              child: widget.onSave == null
                  ? Text(dest.destination.toString(), textAlign: TextAlign.end)
                  : IPAndPortFormField(
                      ipHelp: 'public ip or name',
                      ipTextAlign: TextAlign.end,
                      enableIPV6: true,
                      noBorder: true,
                      initialValue: dest.destination,
                      onSaved: (v) {
                        if (v != null) {
                          dest.destination = v;
                        }
                      },
                    )),
        ]),
      ));
    });

    if (widget.onSave != null) {
      items.add(ConfigButtonItem(
          content: Text('Add another'),
          onPressed: () => setState(() {
                _addDestination();
                _dismissKeyboard();
              })));
    }

    return items;
  }

  _addDestination() {
    changed = true;
    _destinations[UniqueKey()] = _IPAndPort(focusNode: FocusNode(), destination: IPAndPort());
    // We can't onChanged here because it causes rendering issues on first build due to ensuring there is a single destination
  }

  _removeDestination(Key key) {
    changed = true;
    _destinations.remove(key);
  }

  _dismissKeyboard() {
    FocusScopeNode currentFocus = FocusScope.of(context);

    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _destinations.forEach((key, dest) {
      dest.focusNode.dispose();
    });

    super.dispose();
  }
}
