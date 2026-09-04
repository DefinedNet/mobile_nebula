import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    tempDir = await Directory.systemTemp.createTemp('mobile_nebula_settings_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> writeConfig(String contents) => File(p.join(tempDir.path, 'config.json')).writeAsString(contents);

  test('stored settings are visible once ready completes', () async {
    await writeConfig('{"trackErrors": false, "logWrap": true}');

    final settings = Settings.forTesting();
    await settings.ready;

    // main() gates Sentry on this, so a stale default here silently re-enables
    // crash reporting for someone who opted out
    expect(settings.trackErrors, isFalse);
    expect(settings.logWrap, isTrue);
  });

  test('defaults apply when there is no stored config', () async {
    final settings = Settings.forTesting();
    await settings.ready;

    expect(settings.trackErrors, defaultTrackErrors);
    expect(settings.logWrap, defaultLogWrap);
  });

  test('an unparsable config falls back to defaults without hanging ready', () async {
    await writeConfig('{"trackErrors": fal');

    final settings = Settings.forTesting();
    await settings.ready.timeout(const Duration(seconds: 5));

    expect(settings.trackErrors, defaultTrackErrors);
  });

  test('a config holding something other than an object is ignored', () async {
    await writeConfig('["nope"]');

    final settings = Settings.forTesting();
    await settings.ready.timeout(const Duration(seconds: 5));

    expect(settings.logWrap, defaultLogWrap);
  });

  test('a setting written while the load is in flight survives it', () async {
    await writeConfig('{"logWrap": true}');

    final settings = Settings.forTesting();
    settings.logWrap = false;
    await settings.ready;

    expect(settings.logWrap, isFalse);
  });
}
