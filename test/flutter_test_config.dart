import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set a consistent surface size for all tests to ensure pixel-perfect golden matching
  // Using iPhone 13 Pro dimensions: 390x844 logical pixels (1170x2532 physical @ 3x)
  TestWidgetsFlutterBinding.ensureInitialized();
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.implicitView!.physicalSize = const Size(390, 844);
  binding.platformDispatcher.implicitView!.devicePixelRatio = 1.0;

  return testMain();
}
