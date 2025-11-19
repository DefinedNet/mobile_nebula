import 'package:flutter/services.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'dart:async';

class _PollTokenResponse {
  final String token;
  final String url;
  _PollTokenResponse(this.token, this.url);
}

class OIDCPoller {
  final Settings settings; //todo thread safety?
  final MethodChannel platform;
  final MethodChannel bgplatform;

  OIDCPoller(this.settings, this.platform, this.bgplatform);

  Future<_PollTokenResponse?> _getPollToken() async {
    try {
      //todo put a lil spinny somewhere?
      var out = await platform.invokeMethod<Map>("dn.getPollToken");
      if (out == null) {
        print("getPollToken was null");
        return null;
      }
      settings.pollCode = out["pollToken"];
      return _PollTokenResponse(out["pollToken"], out["url"]);
    } on PlatformException catch (err) {
      print(err);
      return null;
    }
  }

  Future<bool> beginLogin() async {
    final resp = await _getPollToken();
    if (resp == null) {
      print('Could not obtain poll token');
      return false;
    }

    try {
      await platform.invokeMethod("dn.popBrowser", resp.url);
      return true;
    } on PlatformException catch (err) {
      print(err);
      return false;
    }
  }

  Future<bool?> pollLoginStatus() async {
    final pollToken = settings.pollCode;

    if (pollToken == "") {
      print('No poll token found');
      return false;
    }

    try {
      await bgplatform.invokeMethod("dn.usePollToken", pollToken);
      print("probably enrolled");
      settings.pollCode = "";
      return true;
    } on PlatformException catch (err) {
      if (err.code == "oidc_enroll_incomplete") {
        print("still thinking! $err");
        return null; //retry I suppose?
      }
      print(err);
      return false;
    }
  }

  Future<bool> pollLoop({
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      final status = await pollLoginStatus();
      if (status != null) {
        // Login completed (success or failure)
        settings.pollCode = "";
        return status;
      } else {
        await Future.delayed(interval);
      }
    }

    // Timeout reached
    settings.pollCode = "";
    return false;
  }
}
