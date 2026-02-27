import 'package:flutter/cupertino.dart';
import 'package:mobile_nebula/components/config/config_button_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/models/unsafe_route.dart';
import 'package:mobile_nebula/screens/siteConfig/unsafe_route_screen.dart';
import 'package:mobile_nebula/services/utils.dart';

class UnsafeRoutesScreen extends StatefulWidget {
  const UnsafeRoutesScreen({super.key, required this.unsafeRoutes, required this.onSave});

  final List<UnsafeRoute> unsafeRoutes;
  final ValueChanged<List<UnsafeRoute>>? onSave;

  @override
  UnsafeRoutesScreenState createState() => UnsafeRoutesScreenState();
}

class UnsafeRoutesScreenState extends State<UnsafeRoutesScreen> {
  late Map<Key, UnsafeRoute> unsafeRoutes;
  bool changed = false;

  @override
  void initState() {
    unsafeRoutes = {};
    for (var route in widget.unsafeRoutes) {
      unsafeRoutes[UniqueKey()] = route;
    }

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

  void _onSave() {
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
