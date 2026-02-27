import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

const platform = MethodChannel('net.defined.mobileNebula/NebulaVpnService');

/// Returns the base directory where native code looks for sites.
/// On Android this is the app's filesDir (== getApplicationSupportDirectory).
/// On iOS this is the app group container shared with the network extension.
Future<Directory> getSitesBaseDir() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return getApplicationSupportDirectory();
  }
  // iOS: sites live in the shared app group container
  final provider = PathProviderFoundation();
  final path = await provider.getContainerPath(appGroupIdentifier: 'group.net.defined.mobileNebula');
  if (path == null) {
    throw StateError('App group container not available');
  }
  return Directory(path);
}

/// Creates a minimal config.json on disk with no firewall rules or configVersion,
/// simulating a site that predates firewall rule storage.
Future<Directory> createPreMigrationSite(String id, {bool managed = false, String? rawConfig}) async {
  final filesDir = await getSitesBaseDir();
  final siteDir = Directory('${filesDir.path}/sites/$id');
  await siteDir.create(recursive: true);

  final config = {
    'name': 'Test Site',
    'id': id,
    'staticHostmap': <String, dynamic>{},
    'unsafeRoutes': <dynamic>[],
    'cert': '',
    'ca': '',
    'lhDuration': 0,
    'port': 0,
    'cipher': 'aes',
    'managed': managed,
    'rawConfig': rawConfig,
  };

  await File('${siteDir.path}/config.json').writeAsString(jsonEncode(config));
  return siteDir;
}

/// Loads all sites via the native method channel and returns the parsed map.
Future<Map<String, dynamic>> loadSites() async {
  final result = await platform.invokeMethod('listSites');
  return jsonDecode(result) as Map<String, dynamic>;
}

/// Deletes a test site directory from disk.
Future<void> cleanupSite(String id) async {
  final filesDir = await getSitesBaseDir();
  final siteDir = Directory('${filesDir.path}/sites/$id');
  if (await siteDir.exists()) {
    await siteDir.delete(recursive: true);
  }
}

/// Reads the config.json back from disk for a given site id.
Future<Map<String, dynamic>> readConfigFromDisk(String id) async {
  final filesDir = await getSitesBaseDir();
  final configFile = File('${filesDir.path}/sites/$id/config.json');
  return jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const unmanagedId = 'test-unmanaged-migration';
  const unmanagedExistingId = 'test-unmanaged-existing';
  const unmanagedMigratedId = 'test-unmanaged-migrated';

  testWidgets('unmanaged site with no rules gets default outbound', (tester) async {
    addTearDown(() => cleanupSite(unmanagedId));
    await createPreMigrationSite(unmanagedId);

    final sites = await loadSites();
    expect(sites.containsKey(unmanagedId), isTrue, reason: 'site should be loaded');

    final site = sites[unmanagedId] as Map<String, dynamic>;
    expect(site['configVersion'], equals(1));

    final inbound = site['inboundRules'] as List;
    expect(inbound, isEmpty);

    final outbound = site['outboundRules'] as List;
    expect(outbound.length, equals(1));
    expect(outbound[0]['protocol'], equals('any'));
    expect(outbound[0]['startPort'], equals(0));
    expect(outbound[0]['endPort'], equals(0));
    expect(outbound[0]['host'], equals('any'));

    // Verify config.json was re-saved with migrated data
    final saved = await readConfigFromDisk(unmanagedId);
    expect(saved['configVersion'], equals(1));
    expect((saved['inboundRules'] as List), isEmpty);
    expect((saved['outboundRules'] as List).length, equals(1));
    expect((saved['outboundRules'] as List)[0]['protocol'], equals('any'));
  });

  testWidgets('unmanaged site with existing rules preserves them', (tester) async {
    addTearDown(() => cleanupSite(unmanagedExistingId));
    final filesDir = await getSitesBaseDir();
    final siteDir = Directory('${filesDir.path}/sites/$unmanagedExistingId');
    await siteDir.create(recursive: true);

    final config = {
      'name': 'Test Site Existing',
      'id': unmanagedExistingId,
      'staticHostmap': <String, dynamic>{},
      'unsafeRoutes': <dynamic>[],
      'cert': '',
      'ca': '',
      'lhDuration': 0,
      'port': 0,
      'cipher': 'aes',
      'managed': false,
      'configVersion': 1,
      'inboundRules': [
        {'protocol': 'tcp', 'startPort': 443, 'endPort': 443, 'host': 'any'},
      ],
      'outboundRules': <dynamic>[],
    };
    await File('${siteDir.path}/config.json').writeAsString(jsonEncode(config));

    final sites = await loadSites();
    expect(sites.containsKey(unmanagedExistingId), isTrue);

    final site = sites[unmanagedExistingId] as Map<String, dynamic>;
    expect(site['configVersion'], equals(1));

    final inbound = site['inboundRules'] as List;
    expect(inbound.length, equals(1));
    expect(inbound[0]['protocol'], equals('tcp'));
    expect(inbound[0]['startPort'], equals(443));
    expect(inbound[0]['endPort'], equals(443));

    final outbound = site['outboundRules'] as List;
    expect(outbound, isEmpty);
  });

  testWidgets('already migrated site is not modified', (tester) async {
    addTearDown(() => cleanupSite(unmanagedMigratedId));
    final filesDir = await getSitesBaseDir();
    final siteDir = Directory('${filesDir.path}/sites/$unmanagedMigratedId');
    await siteDir.create(recursive: true);

    final config = {
      'name': 'Test Site Migrated',
      'id': unmanagedMigratedId,
      'staticHostmap': <String, dynamic>{},
      'unsafeRoutes': <dynamic>[],
      'cert': '',
      'ca': '',
      'lhDuration': 0,
      'port': 0,
      'cipher': 'aes',
      'managed': false,
      'configVersion': 1,
      'inboundRules': [
        {'protocol': 'tcp', 'startPort': 22, 'endPort': 22, 'host': 'any'},
      ],
      'outboundRules': <dynamic>[],
    };
    final configFile = File('${siteDir.path}/config.json');
    await configFile.writeAsString(jsonEncode(config));
    final originalText = await configFile.readAsString();

    final sites = await loadSites();
    expect(sites.containsKey(unmanagedMigratedId), isTrue);

    final site = sites[unmanagedMigratedId] as Map<String, dynamic>;
    expect(site['configVersion'], equals(1));

    final inbound = site['inboundRules'] as List;
    expect(inbound.length, equals(1));
    expect(inbound[0]['protocol'], equals('tcp'));
    expect(inbound[0]['startPort'], equals(22));
    expect(inbound[0]['endPort'], equals(22));

    final outbound = site['outboundRules'] as List;
    expect(outbound, isEmpty);

    // config.json should not have been rewritten
    final savedText = await configFile.readAsString();
    expect(savedText, equals(originalText));
  });
}
