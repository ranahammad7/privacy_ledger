import 'dart:io';

import 'package:privacy_ledger/database/sdk_database.dart';
import 'package:test/test.dart';

void main() {
  late Directory sdkDataDir;

  setUpAll(() async {
    sdkDataDir = await SdkDatabase.resolveBundledSdkDataDir();
  });

  test('loads bundled SDK entries', () async {
    final db = await SdkDatabase.load(sdkDataDir: sdkDataDir);

    expect(db.lookup('google_mobile_ads'), isNotNull);
    expect(db.lookup('google_mobile_ads')!.displayName, 'Google AdMob');
    expect(db.lookup('firebase_core'), isNotNull);
    expect(db.lookup('purchases_flutter'), isNotNull);
    expect(
      db
          .lookup('purchases_flutter')!
          .dataCollected
          .any((d) => d.type == 'purchase_history'),
      isTrue,
    );
  });

  test('override file adds a new package', () async {
    final overrideFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'privacy_ledger_override_add_${DateTime.now().millisecondsSinceEpoch}.yaml',
    );
    addTearDown(() {
      if (overrideFile.existsSync()) overrideFile.deleteSync();
    });

    overrideFile.writeAsStringSync('''
packages:
  - package: custom_analytics
    display_name: Custom Analytics
    data_collected:
      - type: device_id
        purpose: analytics
        shared_with_third_parties: false
        optional: false
    encrypted_in_transit: true
    user_can_request_deletion: true
    requires_xcprivacy_entry: false
''');

    final db = await SdkDatabase.load(
      sdkDataDir: sdkDataDir,
      overridesFile: overrideFile,
    );

    expect(db.lookup('custom_analytics'), isNotNull);
    expect(db.lookup('custom_analytics')!.displayName, 'Custom Analytics');
    // Bundled entries still present.
    expect(db.lookup('google_mobile_ads'), isNotNull);
  });

  test('override file changes a field on an existing package', () async {
    final overrideFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'privacy_ledger_override_edit_${DateTime.now().millisecondsSinceEpoch}.yaml',
    );
    addTearDown(() {
      if (overrideFile.existsSync()) overrideFile.deleteSync();
    });

    overrideFile.writeAsStringSync('''
packages:
  - package: google_mobile_ads
    display_name: AdMob (project override)
    data_collected:
      - type: device_id
        purpose: advertising
        shared_with_third_parties: true
        optional: false
    encrypted_in_transit: true
    user_can_request_deletion: true
    requires_xcprivacy_entry: true
    required_reason_apis: [UserDefaults]
    notes: Overridden for this project.
''');

    final db = await SdkDatabase.load(
      sdkDataDir: sdkDataDir,
      overridesFile: overrideFile,
    );

    final entry = db.lookup('google_mobile_ads')!;
    expect(entry.displayName, 'AdMob (project override)');
    expect(entry.userCanRequestDeletion, isTrue);
    expect(entry.notes, 'Overridden for this project.');
    expect(entry.dataCollected, hasLength(1));
  });

  test('unknownPackages flags unrecognized names', () async {
    final db = await SdkDatabase.load(sdkDataDir: sdkDataDir);

    final unknown = db.unknownPackages([
      'google_mobile_ads',
      'totally_unknown_sdk',
      'purchases_flutter',
      'another_mystery',
    ]);

    expect(unknown, ['another_mystery', 'totally_unknown_sdk']);
  });

  test('bundled yaml files all parse as SdkEntry', () async {
    final db = await SdkDatabase.load(sdkDataDir: sdkDataDir);
    expect(db.entries.length, greaterThanOrEqualTo(3));
    for (final entry in db.entries.values) {
      expect(entry.package, isNotEmpty);
      expect(entry.displayName, isNotEmpty);
    }
  });
}
