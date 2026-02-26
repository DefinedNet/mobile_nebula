import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/components/simple_page.dart';
import 'package:mobile_nebula/services/utils.dart';

class ExcludedAppsScreen extends StatefulWidget {
  const ExcludedAppsScreen({
    super.key,
    required this.excludedApps,
    required this.onSave,
  });

  final List<String> excludedApps;
  final ValueChanged<List<String>>? onSave;

  @override
  ExcludedAppsScreenState createState() => ExcludedAppsScreenState();
}

class _AppInfo {
  final String packageName;
  final String appName;
  final bool isUninstalled;

  _AppInfo({required this.packageName, required this.appName, this.isUninstalled = false});
}

class ExcludedAppsScreenState extends State<ExcludedAppsScreen> {
  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');

  List<_AppInfo> allApps = [];
  List<_AppInfo> filteredApps = [];
  Set<String> selectedApps = {};
  Set<String> alwaysExcludedApps = {};
  // Icons loaded in phase 2, keyed by package name
  Map<String, Uint8List> iconCache = {};
  bool loading = true;
  bool changed = false;
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    selectedApps = Set.from(widget.excludedApps);
    _loadApps();
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    try {
      // Fetch always-excluded apps and installed apps in parallel
      final results = await Future.wait([
        platform.invokeMethod<String>('android.getAlwaysExcludedApps'),
        platform.invokeMethod<String>('android.getInstalledApps'),
      ]);

      final List<dynamic> alwaysExcluded = jsonDecode(results[0]!);
      alwaysExcludedApps = Set.from(alwaysExcluded.cast<String>());

      final List<dynamic> apps = jsonDecode(results[1]!);

      final loaded = apps.map((app) => _AppInfo(
        packageName: app['packageName'] as String,
        appName: app['appName'] as String,
      )).toList();

      // Create synthetic entries for selected apps that are no longer installed
      final installedPackages = loaded.map((a) => a.packageName).toSet();
      final uninstalledSelected = selectedApps.difference(installedPackages);
      for (final pkg in uninstalledSelected) {
        loaded.add(_AppInfo(
          packageName: pkg,
          appName: 'Not installed',
          isUninstalled: true,
        ));
      }

      loaded.sort((a, b) {
        final aAlways = alwaysExcludedApps.contains(a.packageName);
        final bAlways = alwaysExcludedApps.contains(b.packageName);
        final aSelected = selectedApps.contains(a.packageName);
        final bSelected = selectedApps.contains(b.packageName);
        // Uninstalled, always-excluded, and user-selected all sort to the top
        final aTop = a.isUninstalled || aAlways || aSelected;
        final bTop = b.isUninstalled || bAlways || bSelected;
        if (aTop != bTop) return aTop ? -1 : 1;
        // Uninstalled apps sort above other top items
        if (a.isUninstalled != b.isUninstalled) return a.isUninstalled ? -1 : 1;
        return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
      });

      setState(() {
        allApps = loaded;
        _applyFilter();
        loading = false;
      });

      // Phase 2: fetch icons in background, fill in when ready
      _loadIcons(loaded.map((a) => a.packageName).toList());
    } catch (e) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _loadIcons(List<String> packageNames) async {
    const batchSize = 20;
    for (var i = 0; i < packageNames.length; i += batchSize) {
      if (!mounted) return;
      final batch = packageNames.sublist(i, min(i + batchSize, packageNames.length));
      try {
        final String result = await platform.invokeMethod(
          'android.getAppIcons',
          jsonEncode(batch),
        );
        final Map<String, dynamic> raw = jsonDecode(result);

        final updates = <String, Uint8List>{};
        for (final entry in raw.entries) {
          if (entry.value != null) {
            try {
              updates[entry.key] = base64Decode(entry.value as String);
            } catch (_) {}
          }
        }

        if (mounted && updates.isNotEmpty) {
          setState(() {
            iconCache.addAll(updates);
          });
        }
      } catch (_) {}
    }
  }

  void _applyFilter() {
    final q = searchQuery.toLowerCase();
    filteredApps = allApps.where((app) =>
      app.appName.toLowerCase().contains(q) ||
      app.packageName.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Excluded Apps',
      changed: changed,
      scrollable: SimpleScrollable.none,
      hideSave: widget.onSave == null,
      onSave: () {
        Navigator.pop(context);
        widget.onSave?.call(selectedApps.toList());
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: CupertinoSearchTextField(
              controller: searchController,
              placeholder: 'Search apps...',
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  _applyFilter();
                });
              },
            ),
          ),
          if (loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (filteredApps.isEmpty)
            const Expanded(
              child: Center(child: Text('No apps found')),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: filteredApps.length,
                itemBuilder: (context, index) => _buildAppTile(filteredApps[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppTile(_AppInfo app) {
    final isAlwaysExcluded = alwaysExcludedApps.contains(app.packageName);
    final isSelected = isAlwaysExcluded || selectedApps.contains(app.packageName);
    final isReadOnly = widget.onSave == null;

    return Opacity(
      opacity: isAlwaysExcluded ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: ListTile(
          leading: _buildAppIcon(app),
          title: Text(
            app.appName,
            style: TextStyle(
              fontSize: 15,
              fontStyle: app.isUninstalled ? FontStyle.italic : FontStyle.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            isAlwaysExcluded
                ? '${app.packageName} (always excluded)'
                : app.isUninstalled
                    ? '${app.packageName} (not installed)'
                    : app.packageName,
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isReadOnly
              ? (isSelected ? const Icon(Icons.check, color: CupertinoColors.activeBlue) : null)
              : Checkbox.adaptive(
                  value: isSelected,
                  onChanged: isAlwaysExcluded
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              selectedApps.add(app.packageName);
                            } else {
                              selectedApps.remove(app.packageName);
                            }
                            changed = true;
                          });
                        },
                ),
          onTap: (isReadOnly || isAlwaysExcluded)
              ? null
              : () {
                  setState(() {
                    if (selectedApps.contains(app.packageName)) {
                      selectedApps.remove(app.packageName);
                    } else {
                      selectedApps.add(app.packageName);
                    }
                    changed = true;
                  });
                },
        ),
      ),
    );
  }

  Widget _buildAppIcon(_AppInfo app) {
    if (app.isUninstalled) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.remove_circle_outline, size: 24,
            color: CupertinoColors.systemGrey.resolveFrom(context)),
      );
    }
    final bytes = iconCache[app.packageName];
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          cacheWidth: 128,
          cacheHeight: 128,
          errorBuilder: (_, __, ___) => _defaultIcon(),
        ),
      );
    }
    return _defaultIcon();
  }

  Widget _defaultIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.android, size: 24),
    );
  }
}
