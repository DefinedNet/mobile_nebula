import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import 'package:mobile_nebula/components/SimplePage.dart';
import 'package:url_launcher/url_launcher.dart';

class EnrollmentScreen extends StatefulWidget {
  final String? code;
  final StreamController? stream;
  final bool allowCodeEntry;

  static const routeName = '/v1/mobile-enrollment';

  const EnrollmentScreen({super.key, this.code, this.stream, this.allowCodeEntry = false});

  @override
  _EnrollmentScreenState createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  String? error;
  var enrolled = false;
  var enrollInput = TextEditingController();
  String? code;

  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');

  void initState() {
    code = widget.code;
    super.initState();
    _enroll();
  }

  @override
  void dispose() {
    enrollInput.dispose();
    super.dispose();
  }

  _enroll() async {
    try {
      await platform.invokeMethod("dn.enroll", code);
      setState(() {
        enrolled = true;
        if (widget.stream != null) {
          // Signal a new site has been added
          widget.stream!.add(null);
        }
      });
    } on PlatformException catch (err) {
      setState(() {
        error = err.details ?? err.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bodyTextStyle = textTheme.bodyLarge!.apply(color: colorScheme.onPrimary);
    final contactUri = Uri.parse('mailto:support@defined.net');

    Widget child;
    AlignmentGeometry? alignment;

    if (code == null) {
      if (widget.allowCodeEntry) {
        child = _codeEntry();
      } else {
        // No code, show the error
        child = Padding(
            child: Center(child: Text(
              'No valid enrollment code was found.\n\nContact your administrator to obtain a new enrollment code.',
              textAlign: TextAlign.center,

            )),
            padding: EdgeInsets.only(top: 20)
        );
      }

    } else if (this.error != null) {
      // Error while enrolling, display it
      child = Center(child: Column(
        children: [
          Padding(
            child: SelectableText('There was an issue while attempting to enroll this device. Contact your administrator to obtain a new enrollment code.'),
            padding: EdgeInsets.symmetric(vertical: 20)
          ),
          Padding(child: SelectableText.rich(TextSpan(children: [
              TextSpan(text: 'If the problem persists, please let us know at '),
              TextSpan(
                text: 'support@defined.net',
                style: bodyTextStyle.apply(color: colorScheme.primary),
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    if (await canLaunchUrl(contactUri)) {
                      print(await launchUrl(contactUri));
                    }
                  },
              ),
              TextSpan(text: ' and provide the following error:'),
          ])), padding: EdgeInsets.only(bottom: 10)),
          Container(
            child: Padding(child: SelectableText(this.error!), padding: EdgeInsets.all(10)),
            color: Theme.of(context).colorScheme.errorContainer,
          ),
        ],
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
      ));

    } else if (this.enrolled) {
      // Enrollment complete!
      child = Padding(
          child: Center(child: Text(
            'Enrollment complete! 🎉',
            textAlign: TextAlign.center,
          )),
          padding: EdgeInsets.only(top: 20)
      );

    } else {
      // Have a code and actively enrolling
      alignment = Alignment.center;
      child = Center(child: Column(
        children: [
          Padding(child: Text('Contacting DN for enrollment'), padding: EdgeInsets.only(bottom: 25)),
          PlatformCircularProgressIndicator(cupertino: (_, __) {
            return CupertinoProgressIndicatorData(radius: 50);
          })
        ]
      ));
    }

    return SimplePage(title: Text('DN Enrollment'), child: Padding(child: child, padding: EdgeInsets.symmetric(horizontal: 10)), alignment: alignment);
  }

  Widget _codeEntry() {
    return Column(children: [
      Container(height: 20),
      PlatformTextField(controller: enrollInput),
      CupertinoButton(child: Text('Enroll'), onPressed: () {
        setState(() {
          code = enrollInput.text;
          error = null;
          _enroll();
        });
      }),
    ]);
  }
}
