import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:mobile_nebula/services/storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

bool defaultLogWrap = false;
bool defaultTrackErrors = true;

class Settings {
  final _storage = Storage();
  final StreamController _change = StreamController.broadcast();
  var _settings = <String, dynamic>{};

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

  Settings._internal() {
    _storage.readFile("config.json").then((rawConfig) {
      if (rawConfig != null) {
        _settings = jsonDecode(rawConfig);
      }

      _change.add(null);
    });
  }

  void dispose() {
    _change.close();
  }
}
