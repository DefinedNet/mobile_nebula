import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/models/certificate.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/models/static_hosts.dart';
import 'package:mobile_nebula/models/unsafe_route.dart';
import 'package:mobile_nebula/services/theme.dart';

/// Creates a MaterialApp wrapper for testing widgets
Widget createTestApp({required Widget child}) {
  // Use a simple default text theme since we can't easily create one without a BuildContext
  final textTheme = Typography.material2021().black;
  MaterialTheme theme = MaterialTheme(textTheme);

  return MaterialApp(
    theme: theme.light(),
    darkTheme: theme.dark(),
    home: Scaffold(body: child),
  );
}

/// Creates a mock Site for testing
/// Note: This creates a Site instance but does not set up platform channels
/// Tests using this should mock platform calls or avoid triggering them
Site createMockSite({
  String? name,
  String? id,
  Map<String, StaticHost>? staticHostmap,
  List<CertificateInfo>? ca,
  CertificateInfo? certInfo,
  int? lhDuration,
  int? port,
  String? cipher,
  int? sortKey,
  int? mtu,
  bool? connected,
  String? status,
  String? logFile,
  String? logVerbosity,
  List<String>? errors,
  List<UnsafeRoute>? unsafeRoutes,
  bool? managed,
  String? rawConfig,
  DateTime? lastManagedUpdate,
}) {
  // Create a site with test-friendly defaults
  return MockSite(
    name: name ?? 'Test Site',
    id: id ?? 'test-site-id',
    staticHostmap: staticHostmap ?? {},
    ca: ca ?? [],
    certInfo: certInfo,
    lhDuration: lhDuration ?? 0,
    port: port ?? 4242,
    cipher: cipher ?? "aes",
    sortKey: sortKey ?? 0,
    mtu: mtu ?? 1300,
    connected: connected ?? false,
    status: status ?? 'Disconnected',
    logFile: logFile ?? '',
    logVerbosity: logVerbosity ?? 'info',
    errors: errors ?? [],
    unsafeRoutes: unsafeRoutes ?? [],
    managed: managed ?? false,
    rawConfig: rawConfig,
    lastManagedUpdate: lastManagedUpdate,
  );
}

/// A mock Site that doesn't try to set up EventChannel
class MockSite extends Site {
  MockSite({
    required super.name,
    required super.id,
    required super.staticHostmap,
    required super.ca,
    required super.certInfo,
    required super.lhDuration,
    required super.port,
    required super.cipher,
    required super.sortKey,
    required super.mtu,
    required super.connected,
    required super.status,
    required super.logFile,
    required super.logVerbosity,
    required super.errors,
    required super.unsafeRoutes,
    required super.managed,
    required super.rawConfig,
    required super.lastManagedUpdate,
  }) {
    // Override the initialization to prevent EventChannel setup
    _mockChangeController = StreamController.broadcast();
  }

  late StreamController _mockChangeController;

  @override
  Stream onChange() => _mockChangeController.stream;

  @override
  void dispose() {
    _mockChangeController.close();
    super.dispose();
  }

  /// Simulate a site change event
  void simulateChange() {
    _mockChangeController.add(null);
  }

  /// Simulate a site error event
  void simulateError(String error) {
    _mockChangeController.addError(error);
  }
}

/// Pump frames until there are no more scheduled frames
Future<void> pumpUntilSettled(WidgetTester tester) async {
  await tester.pumpAndSettle();
  // Give extra time for async operations
  await tester.pump(const Duration(milliseconds: 100));
}
