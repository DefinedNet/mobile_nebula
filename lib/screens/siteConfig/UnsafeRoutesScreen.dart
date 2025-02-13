import 'package:flutter/cupertino.dart';
import 'package:mobile_nebula/components/FormPage.dart';
import 'package:mobile_nebula/components/config/ConfigButtonItem.dart';
import 'package:mobile_nebula/components/config/ConfigPageItem.dart';
import 'package:mobile_nebula/components/config/ConfigSection.dart';
import 'package:mobile_nebula/models/UnsafeRoute.dart';
import 'package:mobile_nebula/screens/siteConfig/UnsafeRouteScreen.dart';
import 'package:mobile_nebula/services/utils.dart';

class UnsafeRoutesScreen extends StatefulWidget {
  const UnsafeRoutesScreen({super.key, required this.unsafeRoutes, required this.onSave});

  final List<UnsafeRoute> unsafeRoutes;
  final ValueChanged<List<UnsafeRoute>>? onSave;

  @override
  _UnsafeRoutesScreenState createState() => _UnsafeRoutesScreenState();
}

class _UnsafeRoutesScreenState extends State<UnsafeRoutesScreen> {
  late Map<Key, UnsafeRoute> unsafeRoutes;
  bool changed = false;

  @override
  void initState() {
    unsafeRoutes = {};
    widget.unsafeRoutes.forEach((route) {
      unsafeRoutes[UniqueKey()] = route;
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Unsafe Routes',
      changed: changed,
      onSave: _onSave,
      child: ConfigSection(children: _buildRoutes()),
    );
  }

  _onSave() {
    Navigator.pop(context);
    if (widget.onSave != null) {
      widget.onSave!(unsafeRoutes.values.toList());
    }
  }

  List<Widget> _buildRoutes() {
    final double ipWidth = Utils.textSize("000.000.000.000/00", CupertinoTheme.of(context).textTheme.textStyle).width;
    List<Widget> items = [];
    unsafeRoutes.forEach((key, route) {
      items.add(
        ConfigPageItem(
          disabled: widget.onSave == null,
          label: Text(route.route ?? ''),
          labelWidth: ipWidth,
          content: Text('via ${route.via}', textAlign: TextAlign.end),
          onPressed: () {
            Utils.openPage(context, (context) {
              return UnsafeRouteScreen(
                route: route,
                onSave: (route) {
                  setState(() {
                    changed = true;
                    unsafeRoutes[key] = route;
                  });
                },
                onDelete: () {
                  setState(() {
                    changed = true;
                    unsafeRoutes.remove(key);
                  });
                },
              );
            });
          },
        ),
      );
    });

    if (widget.onSave != null) {
      items.add(
        ConfigButtonItem(
          content: Text('Add a new route'),
          onPressed: () {
            Utils.openPage(context, (context) {
              return UnsafeRouteScreen(
                route: UnsafeRoute(),
                onSave: (route) {
                  setState(() {
                    changed = true;
                    unsafeRoutes[UniqueKey()] = route;
                  });
                },
              );
            });
          },
        ),
      );
    }

    return items;
  }
}
