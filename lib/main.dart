import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoThemeData, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart'
    show BottomSheetThemeData, Colors, DefaultMaterialLocalizations, Theme, ThemeData, ThemeMode;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/screens/MainScreen.dart';
import 'package:mobile_nebula/screens/EnrollmentScreen.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

//TODO: EventChannel might be better than the stream controller we are using now

void main() {
  usePathUrlStrategy();
  runApp(Main());
}

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
        if (!settings.useSystemColors) {
          brightness = settings.darkMode ? Brightness.dark : Brightness.light;
        }
      });
    });

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
      brightness: Brightness.light,
      primarySwatch: Colors.blueGrey,
      primaryColor: Colors.blueGrey[900],
      fontFamily: 'PublicSans',
      //scaffoldBackgroundColor: Colors.grey[100],
      scaffoldBackgroundColor: Colors.white,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.blueGrey[50],
      ),
    );

    final ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.grey,
      primaryColor: Colors.grey[900],
      fontFamily: 'PublicSans',
      scaffoldBackgroundColor: Colors.grey[800],
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.grey[850],
      ),
    );

    // This theme is required since icons light/dark mode will look for it
    return Theme(
      data: brightness == Brightness.light ? lightTheme : darkTheme,
      child: PlatformProvider(
        //initialPlatform: initialPlatform,
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
      ),
    );
  }
}
