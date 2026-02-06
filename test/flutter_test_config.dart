import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set a consistent surface size for all tests to ensure pixel-perfect golden matching
  // Using iPhone 13 Pro dimensions: 390x844 logical pixels
  // Note: devicePixelRatio must be set in individual tests using tester.view.devicePixelRatio = 1.0
  TestWidgetsFlutterBinding.ensureInitialized();
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.implicitView!.physicalSize = const Size(390, 844);

  return testMain();
}
