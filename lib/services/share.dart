// This code comes from https://github.com/lubritto/flutter_share with bugfixes for ipad
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Share {
  static const _channel = MethodChannel('net.defined.mobileNebula/NebulaVpnService');

  /// Shares a string of text
  /// - title: Title of message or subject if sending an email
  /// - text: The text to share
  /// - filename: The filename to use if sending over airdrop for example
  static Future<bool> share({
    required String title,
    required String text,
    required String filename,
  }) async {
    assert(title.isNotEmpty);
    assert(text.isNotEmpty);
    assert(filename.isNotEmpty);

    if (title.isEmpty) {
      throw FlutterError('Title cannot be empty');
    }

    final bool success = await _channel.invokeMethod('share', <String, dynamic>{
      'title': title,
      'text': text,
      'filename': filename,
    });

    return success;
  }

  /// Shares a local file
  /// - title: Title of message or subject if sending an email
  /// - filePath: Path to the file to share
  /// - filename: An optional filename to override the existing file
  static Future<bool> shareFile({
    required String title,
    required String filePath,
    String? filename,
  }) async {
    assert(title.isNotEmpty);
    assert(filePath.isNotEmpty);

    if (title.isEmpty) {
      throw FlutterError('Title cannot be empty');
    } else if (filePath.isEmpty) {
      throw FlutterError('FilePath cannot be empty');
    }

    final bool success = await _channel.invokeMethod('shareFile', <String, dynamic>{
      'title': title,
      'filePath': filePath,
      'filename': filename,
    });

    return success;
  }
}
