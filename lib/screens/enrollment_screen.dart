import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:logging/logging.dart';
import 'package:mobile_nebula/components/buttons/primary_button.dart';
import 'package:mobile_nebula/components/simple_page.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/config/config_section.dart';

final _log = Logger('enrollment_screen');

class EnrollmentScreen extends StatefulWidget {
  final String? code;
  final StreamController? stream;
  final bool allowCodeEntry;

  static const routeName = '/v1/mobile-enrollment';

  // Attempts to find an enrollment code in the provided url. If one is not found then assume the input was
  // an enrollment code. Primarily to support manual dn enrollment where the user can input a code or a url.
  static String parseCode(String url) {
    final uri = Uri.parse(url);
    if (uri.path != EnrollmentScreen.routeName) {
      return url;
    }

    if (uri.hasFragment) {
      final qp = Uri.splitQueryString(uri.fragment);
      return qp["code"] ?? "";
    }

    return url;
  }

  const EnrollmentScreen({super.key, this.code, this.stream, this.allowCodeEntry = false});

  @override
  EnrollmentScreenState createState() => EnrollmentScreenState();
}

class EnrollmentScreenState extends State<EnrollmentScreen> {
  String? error;
  var enrolled = false;
  var enrollInput = TextEditingController();
  String? code;

  static const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');

  @override
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

  Future<void> _enroll() async {
    if (code == null) {
      return; //nothing to do
    }
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
          padding: EdgeInsets.only(top: 20),
          child: Center(
            child: Text(
              'No valid enrollment code was found.\n\nContact your administrator to obtain a new enrollment code.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
    } else if (error != null) {
      // Error while enrolling, display it
      child = Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: SelectableText(
                'There was an issue while attempting to enroll this device. Contact your administrator to obtain a new enrollment code.',
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'If the problem persists, please let us know at '),
                    TextSpan(
                      text: 'support@defined.net',
                      style: bodyTextStyle.apply(color: colorScheme.primary),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          if (await canLaunchUrl(contactUri)) {
                            _log.info(await launchUrl(contactUri));
                          }
                        },
                    ),
                    TextSpan(text: ' and provide the following error:'),
                  ],
                ),
              ),
            ),
            Container(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(padding: EdgeInsets.all(16), child: SelectableText(error!)),
            ),
          ],
        ),
      );
    } else if (enrolled) {
      // Enrollment complete!
      child = Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(child: Text('Enrollment complete! 🎉', textAlign: TextAlign.center)),
      );
    } else {
      // Have a code and actively enrolling
      alignment = Alignment.center;
      child = Center(
        child: Column(
          children: [
            Padding(padding: EdgeInsets.only(bottom: 25), child: Text('Contacting DN for enrollment')),
            PlatformCircularProgressIndicator(
              cupertino: (_, _) {
                return CupertinoProgressIndicatorData(radius: 50);
              },
            ),
          ],
        ),
      );
    }

    return SimplePage(title: Text('Enroll with Managed Nebula'), alignment: alignment, child: child);
  }

  Widget _codeEntry() {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    String? validator(String? value) {
      if (value == null || value.isEmpty) {
        return 'Code or link is required';
      }
      return null;
    }

    Future<void> onSubmit() async {
      final bool isValid = formKey.currentState?.validate() ?? false;
      if (!isValid) {
        return;
      }

      setState(() {
        code = EnrollmentScreen.parseCode(enrollInput.text);
        error = null;
        _enroll();
      });
    }

    final input = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: PlatformTextFormField(
        controller: enrollInput,
        validator: validator,
        hintText: 'from admin.defined.net',
        cupertino: (_, _) => CupertinoTextFormFieldData(prefix: Text("Code or link")),
        material: (_, _) => MaterialTextFormFieldData(decoration: const InputDecoration(labelText: 'Code or link')),
      ),
    );

    final form = Form(
      key: formKey,
      child: Platform.isAndroid ? input : ConfigSection(children: [input]),
    );

    return Column(
      children: [
        Padding(padding: EdgeInsets.symmetric(vertical: 32), child: form),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: PrimaryButton(onPressed: onSubmit, child: Text('Submit')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
