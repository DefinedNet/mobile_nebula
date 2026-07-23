import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mobile_nebula/main.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Utils {
  /// Minimum size (width or height) of a interactive component
  static const double minInteractiveSize = 48;

  /// The top and bottom border color of a config section
  static Color configSectionBorder(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static Size textSize(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  static void openPage(BuildContext context, WidgetBuilder pageToDisplayBuilder) {
    Navigator.push(context, MaterialPageRoute(builder: pageToDisplayBuilder));
  }

  static String itemCountFormat(int items, {String singleSuffix = "item", String multiSuffix = "items"}) {
    if (items == 1) {
      return "$items $singleSuffix";
    }

    return "$items $multiSuffix";
  }

  /// Builds a simple leading widget that pops the current screen.
  /// Provide your own onPressed to override that behavior, just remember you have to pop
  static Widget leadingBackWidget(BuildContext context, {label = 'Back', Function? onPressed}) {
    return IconButton(
      padding: EdgeInsets.zero,
      icon: Icon(Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back),
      tooltip: label,
      onPressed: () {
        if (onPressed == null) {
          Navigator.pop(context);
        } else {
          onPressed();
        }
      },
    );
  }

  static Widget trailingSaveWidget(BuildContext context, Function onPressed) {
    return TextButton(onPressed: () => onPressed(), child: Text('Save'));
  }

  /// Simple cross platform delete confirmation dialog - can also be used to confirm throwing away a change by swapping the deleteLabel
  static void confirmDelete(
    BuildContext context,
    String title,
    Function onConfirm, {
    String deleteLabel = 'Delete',
    String cancelLabel = 'Cancel',
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          actions: <Widget>[
            TextButton(
              child: Text(
                deleteLabel,
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error),
              ),
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
            ),
            TextButton(
              child: Text(cancelLabel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  static void popError(String title, String error, {StackTrace? stack}) {
    if (stack != null) {
      error += '\n${stack.toString()}';
    }

    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(error),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> launchUrl(String url) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      Utils.popError('Error', 'Could not launch web view');
    }
  }

  static Future<String?> pickFile(BuildContext context) async {
    final file = await openFile();
    if (file == null) {
      return null;
    }

    final content = await file.readAsString();

    // We get a copy, not the original, so don't leave a plaintext key sitting around
    try {
      await File(file.path).delete();
    } catch (err) {
      // Ignoring file delete errors
    }

    return content;
  }

  /// Deletes copies left behind by file_picker, which we used to use. It only cleared
  /// its cache on the next pick, so the last thing anyone imported is still in there.
  static Future<void> clearLegacyPickedFiles() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final legacyCache = Directory(p.join(cacheDir.path, 'file_picker'));
      if (legacyCache.existsSync()) {
        legacyCache.deleteSync(recursive: true);
      }
    } catch (err) {
      // Ignoring cleanup errors
    }

    // iOS document imports land in <tmp>/<bundle id>-Inbox. systemTemp because
    // path_provider points getTemporaryDirectory at Library/Caches, not tmp, and it
    // is only our sandbox on iOS. Inboxes only, Share is using the rest of tmp.
    if (!Platform.isIOS) {
      return;
    }

    try {
      for (final entry in Directory.systemTemp.listSync()) {
        if (entry is Directory && entry.path.endsWith('-Inbox')) {
          entry.deleteSync(recursive: true);
        }
      }
    } catch (err) {
      // Ignoring cleanup errors
    }
  }

  static TextTheme createTextTheme() {
    // Use Android's Material text geometry as the base so font sizes are
    // consistent across iOS and Android (avoids iOS 17px default).
    final typography = Typography.material2021(platform: TargetPlatform.android);
    TextTheme baseTextTheme = typography.englishLike.merge(typography.black);
    // Apply Inter font family to all styles. The font files are bundled
    // in fonts/ and declared in pubspec.yaml — no HTTP fetching needed.
    return baseTextTheme.apply(fontFamily: 'Inter');
  }

  static (int, bool) dynamicToInt(dynamic d) {
    if (d is String) {
      final i = int.tryParse(d);
      if (i == null) {
        return (0, false);
      }
      return (i, true);
    } else if (d is num) {
      return (d.toInt(), true);
    }

    return (0, false);
  }
}
