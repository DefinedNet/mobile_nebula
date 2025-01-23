import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:google_fonts/google_fonts.dart';

class Utils {
  /// Minimum size (width or height) of a interactive component
  static const double minInteractiveSize = 44;

  /// The background color for a page, this is the furthest back color
  static Color pageBackground(BuildContext context) {
    return CupertinoColors.systemGroupedBackground.resolveFrom(context);
  }

  /// The background color for a config item
  static Color configItemBackground(BuildContext context) {
    return CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
  }

  /// The top and bottom border color of a config section
  static Color configSectionBorder(BuildContext context) {
    return CupertinoColors.secondarySystemFill.resolveFrom(context);
  }

  static Size textSize(String text, TextStyle style) {
    final TextPainter textPainter =
        TextPainter(text: TextSpan(text: text, style: style), maxLines: 1, textDirection: TextDirection.ltr)
          ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  static openPage(BuildContext context, WidgetBuilder pageToDisplayBuilder) {
    Navigator.push(
      context,
      platformPageRoute(
        context: context,
        builder: pageToDisplayBuilder,
      ),
    );
  }

  static String itemCountFormat(int items, {singleSuffix = "item", multiSuffix = "items"}) {
    if (items == 1) {
      return items.toString() + " " + singleSuffix;
    }

    return items.toString() + " " + multiSuffix;
  }

  /// Builds a simple leading widget that pops the current screen.
  /// Provide your own onPressed to override that behavior, just remember you have to pop
  static Widget leadingBackWidget(BuildContext context, {label = 'Back', Function? onPressed}) {
    if (Platform.isIOS) {
      return CupertinoNavigationBarBackButton(
          previousPageTitle: label,
          onPressed: () {
            if (onPressed == null) {
              Navigator.pop(context);
            } else {
              onPressed();
            }
          });
    }

    return IconButton(
      padding: EdgeInsets.zero,
      icon: Icon(context.platformIcons.back),
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
    return PlatformTextButton(
        child: Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        padding: Platform.isAndroid ? null : EdgeInsets.zero,
        onPressed: () => onPressed());
  }

  /// Simple cross platform delete confirmation dialog - can also be used to confirm throwing away a change by swapping the deleteLabel
  static confirmDelete(BuildContext context, String title, Function onConfirm,
      {String deleteLabel = 'Delete', String cancelLabel = 'Cancel'}) {
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PlatformAlertDialog(
            title: Text(title),
            actions: <Widget>[
              PlatformDialogAction(
                child: Text(deleteLabel,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.systemRed.resolveFrom(context))),
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
              ),
              PlatformDialogAction(
                child: Text(cancelLabel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  static popError(BuildContext context, String title, String error, {StackTrace? stack}) {
    if (stack != null) {
      error += '\n${stack.toString()}';
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          if (Platform.isAndroid) {
            return AlertDialog(title: Text(title), content: Text(error), actions: <Widget>[
              TextButton(
                child: Text('Ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ]);
          }

          return CupertinoAlertDialog(
            title: Text(title),
            content: Text(error),
            actions: <Widget>[
              CupertinoDialogAction(
                child: Text('Ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  static launchUrl(String url, BuildContext context) async {
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      Utils.popError(context, 'Error', 'Could not launch web view');
    }
  }

  static int ip2int(String ip) {
    final parts = ip.split('.');
    return int.parse(parts[3]) | int.parse(parts[2]) << 8 | int.parse(parts[1]) << 16 | int.parse(parts[0]) << 24;
  }

  static Future<String?> pickFile(BuildContext context) async {
    await FilePicker.platform.clearTemporaryFiles();
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null) {
      return null;
    }

    final file = File(result.files.first.path!);
    return file.readAsString();
  }

  static TextTheme createTextTheme(BuildContext context, String bodyFontString, String displayFontString) {
    TextTheme baseTextTheme = Theme.of(context).textTheme;
    TextTheme bodyTextTheme = GoogleFonts.getTextTheme(bodyFontString, baseTextTheme);
    TextTheme displayTextTheme = GoogleFonts.getTextTheme(displayFontString, baseTextTheme);
    TextTheme textTheme = displayTextTheme.copyWith(
      bodyLarge: bodyTextTheme.bodyLarge,
      bodyMedium: bodyTextTheme.bodyMedium,
      bodySmall: bodyTextTheme.bodySmall,
      labelLarge: bodyTextTheme.labelLarge,
      labelMedium: bodyTextTheme.labelMedium,
      labelSmall: bodyTextTheme.labelSmall,
    );
    return textTheme;
  }
}
