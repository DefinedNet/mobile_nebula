import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/main.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mobile_nebula_app_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);

    // MainScreen talks to the VPN service from initState, stub it so the tree builds
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('net.defined.mobileNebula/NebulaVpnService'),
      (call) async => call.method == 'listSites' ? '{}' : null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('net.defined.mobileNebula/NebulaVpnService'),
      null,
    );
    await tempDir.delete(recursive: true);
  });

  testWidgets('stored dark mode is applied on the first build', (tester) async {
    // System colors off with dark mode on, on a light-mode device, so the stored
    // preference is the only thing that can produce a dark theme.
    await tester.runAsync(() async {
      await File(p.join(tempDir.path, 'config.json')).writeAsString('{"systemDarkMode": false, "darkMode": true}');

      // Mirrors main(), which awaits the load before it builds the app. The load's
      // change event fires here, before AppState exists to hear it.
      await Settings().ready;
    });

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const App());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
