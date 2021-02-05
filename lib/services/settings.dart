import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:mobile_nebula/services/storage.dart';

class Settings {
  final _storage = Storage();
  StreamController _change = StreamController.broadcast();
  var _ready = Completer<Settings>();
  var _settings = Map<String, dynamic>();

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
    return _getBool('darkMode', SchedulerBinding.instance.window.platformBrightness == Brightness.dark);
  }

  set darkMode(bool enabled) {
    _set('darkMode', enabled);
  }

  bool get logWrap {
    return _getBool('logWrap', false);
  }

  set logWrap(bool enabled) {
    _set('logWrap', enabled);
  }

  String _getString(String key, String defaultValue) {
    final val = _settings[key];
    if (val is String) {
      return val;
    }
    return defaultValue;
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
    _ready = Completer<Settings>();

    _storage.readFile("config.json").then((rawConfig) {
      if (rawConfig != null) {
        _settings = jsonDecode(rawConfig);
      }

      _ready.complete();
      _change.add(null);
    });
  }

  void dispose() {
    _change.close();
  }
}
