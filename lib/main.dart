import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoThemeData, DefaultCupertinoLocalizations, CupertinoColors;
import 'package:flutter/material.dart'
    show BottomSheetThemeData, ColorScheme, Colors, DefaultMaterialLocalizations, ThemeData, ThemeMode;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/screens/MainScreen.dart';
import 'package:mobile_nebula/screens/EnrollmentScreen.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  usePathUrlStrategy();

  var settings = Settings();
  if (settings.trackErrors) {
    await SentryFlutter.init(
      (options) {
        options.dsn = 'https://96106df405ade3f013187dfc8e4200e7@o920269.ingest.us.sentry.io/4508132321001472';
        // Capture all traces.  May need to adjust if overwhelming
        options.tracesSampleRate = 1.0;
        // For each trace, capture all profiles
        options.profilesSampleRate = 1.0;
      },
      appRunner: () => runApp(Main()),
    );
  } else {
    runApp(Main());
  }
}

//TODO: EventChannel might be better than the stream controller we are using now

class Main extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) => App();
}

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  final settings = Settings();
  Brightness brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
  StreamController dnEnrolled = StreamController.broadcast();

  @override
  void initState() {
    //TODO: wait until settings is ready?
    settings.onChange().listen((_) {
      setState(() {
        if (settings.useSystemColors) {
          brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
        } else {
          brightness = settings.darkMode ? Brightness.dark : Brightness.light;
        }
      });
    });

    // Listen to changes to the system brightness mode, update accordingly
    final dispatcher = SchedulerBinding.instance.platformDispatcher;
    dispatcher.onPlatformBrightnessChanged = () {
      if (settings.useSystemColors) {
        setState(() {
          brightness = dispatcher.platformBrightness;
        });
      }
    };

    super.initState();
  }

  @override
  void dispose() {
    dnEnrolled.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData lightTheme = ThemeData(
      useMaterial3: false,
      colorScheme: ColorScheme.fromSwatch(
        brightness: Brightness.light,
        primarySwatch: Colors.blueGrey,
        errorColor: CupertinoColors.systemRed.resolveFrom(context),
      ),
      primaryColor: Colors.blueGrey[900],
      fontFamily: 'PublicSans',
      //scaffoldBackgroundColor: Colors.grey[100],
      scaffoldBackgroundColor: Colors.white,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.blueGrey[50],
      ),
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: false,
      colorScheme: ColorScheme.fromSwatch(
        brightness: Brightness.dark,
        primarySwatch: Colors.grey,
        errorColor: CupertinoColors.systemRed.resolveFrom(context),
      ),
      primaryColor: Colors.grey[900],
      fontFamily: 'PublicSans',
      scaffoldBackgroundColor: Colors.grey[800],
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.grey[850],
      ),
    );

    return PlatformProvider(
      settings: PlatformSettingsData(iosUsesMaterialWidgets: true),
      builder: (context) => PlatformApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        title: 'Nebula',
        material: (_, __) {
          return new MaterialAppData(
            themeMode: brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
            theme: brightness == Brightness.light ? lightTheme : darkTheme,
          );
        },
        cupertino: (_, __) => CupertinoAppData(
          theme: CupertinoThemeData(brightness: brightness),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return platformPageRoute(context: context, builder: (context) => MainScreen(this.dnEnrolled));
          }

          final uri = Uri.parse(settings.name!);
          if (uri.path == EnrollmentScreen.routeName) {
            // TODO: maybe implement this as a dialog instead of a page, you can stack multiple enrollment screens which is annoying in dev
            return platformPageRoute(
              context: context,
              builder: (context) =>
                  EnrollmentScreen(code: EnrollmentScreen.parseCode(settings.name!), stream: this.dnEnrolled),
            );
          }

          return null;
        },
      ),
    );
  }
}
