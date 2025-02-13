import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as sp;
import 'package:path/path.dart' as p;

class Share {
  /// Transforms a string of text into a file and shares that file
  /// - title: Title of message or subject if sending an email
  /// - text: The text to share
  /// - filename: The filename to use if sending over airdrop for example
  static Future<bool> share(
    BuildContext context, {
    required String title,
    required String text,
    required String filename,
  }) async {
    assert(title.isNotEmpty);
    assert(text.isNotEmpty);
    assert(filename.isNotEmpty);

    final tmpDir = await getTemporaryDirectory();
    final file = File(p.join(tmpDir.path, filename));
    var res = false;

    try {
      file.writeAsStringSync(text, flush: true);
      res = await Share.shareFile(context, title: title, filePath: file.path);
    } catch (err) {
      // Ignoring file write errors
    }

    file.delete();
    return res;
  }

  /// Shares a local file
  /// - title: Title of message or subject if sending an email
  /// - filePath: Path to the file to share
  /// - filename: An optional filename to override the existing file
  static Future<bool> shareFile(
    BuildContext context, {
    required String title,
    required String filePath,
    String? filename,
  }) async {
    assert(title.isNotEmpty);
    assert(filePath.isNotEmpty);

    final box = context.findRenderObject() as RenderBox?;

    //NOTE: the filename used to specify the name of the file in gmail/slack/etc but no longer works that way
    // If we want to support that again we will need to save the file to a temporary directory, share that,
    // and then delete it
    final xFile = sp.XFile(filePath, name: filename);
    final result = await sp.Share.shareXFiles(
      [xFile],
      subject: title,
      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
    );
    return result.status == sp.ShareResultStatus.success;
  }
}
