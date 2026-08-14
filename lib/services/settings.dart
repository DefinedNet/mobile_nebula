import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mobile_nebula/services/storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

bool defaultLogWrap = false;
bool defaultTrackErrors = true;

class Settings {
  final _storage = Storage();
  final StreamController _change = StreamController.broadcast();
  final _settings = <String, dynamic>{};

  /// Completes once config.json has been loaded. Anything that reads a setting
  /// before this resolves will see defaults, not what the user has stored.
  late final Future<void> ready;

  bool get useSystemColors {
    return _getBool('systemDarkMode', true);
  }

  set useSystemColors(bool enabled) {
    if (!enabled) {
      // Clear the dark mode to let the default system config take over, user can override from there
      _settings.remove('darkMode');
    }
    _set('systemDarkMode', enabled);
  }

  bool get darkMode {
    return _getBool('darkMode', SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
  }

  set darkMode(bool enabled) {
    _set('darkMode', enabled);
  }

  bool get logWrap {
    return _getBool('logWrap', defaultLogWrap);
  }

  set logWrap(bool enabled) {
    _set('logWrap', enabled);
  }

  bool get trackErrors {
    return _getBool('trackErrors', defaultTrackErrors);
  }

  set trackErrors(bool enabled) {
    _set('trackErrors', enabled);

    // Side-effect: Disable Sentry immediately
    if (!enabled) {
      Sentry.close();
    }
  }

  bool _getBool(String key, bool defaultValue) {
    final val = _settings[key];
    if (val is bool) {
      return val;
    }
    return defaultValue;
  }

  void _set(String key, dynamic value) {
    _settings[key] = value;
    _save();
  }

  Stream onChange() {
    return _change.stream;
  }

  void _save() {
    final content = jsonEncode(_settings);
    //TODO: handle errors
    _storage.writeFile("config.json", content).then((_) {
      _change.add(null);
    });
  }

  static final Settings _instance = Settings._internal();

  factory Settings() {
    return _instance;
  }

  /// Builds an isolated instance so tests can exercise the load more than once.
  /// App code should always go through the Settings() singleton.
  @visibleForTesting
  factory Settings.forTesting() {
    return Settings._internal();
  }

  Settings._internal() {
    ready = _load();
  }

  Future<void> _load() async {
    final rawConfig = await _storage.readFile("config.json");

    try {
      final decoded = rawConfig == null ? null : jsonDecode(rawConfig);
      if (decoded is Map<String, dynamic>) {
        // putIfAbsent rather than assignment so that any setting written while
        // the read was in flight wins over the on disk copy it predates
        decoded.forEach((key, value) => _settings.putIfAbsent(key, () => value));
      }
    } catch (_) {
      // Unparsable config, carry on with the defaults rather than leaving
      // listeners waiting on a change event that never arrives
    }

    _change.add(null);
  }

  void dispose() {
    _change.close();
  }
}
