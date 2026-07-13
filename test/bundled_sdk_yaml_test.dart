import 'dart:io';

import 'package:privacy_ledger/database/sdk_database.dart';
import 'package:test/test.dart';

void main() {
  test('all bundled YAML files parse successfully via SdkDatabase', () async {
    final db = await SdkDatabase.load();
    final dir = await SdkDatabase.resolveBundledSdkDataDir();
    final yamlFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
        .toList();

    expect(yamlFiles, isNotEmpty);
    expect(db.entries.length, yamlFiles.length);

    const required = [
      'google_mobile_ads',
      'firebase_core',
      'purchases_flutter',
      'flutter_stripe',
      'shared_preferences',
      'image_picker',
      'file_picker',
    ];

    for (final name in required) {
      expect(db.lookup(name), isNotNull, reason: 'missing $name');
      expect(db.lookup(name)!.package, name);
      expect(db.lookup(name)!.displayName, isNotEmpty);
    }

    for (final entry in db.entries.values) {
      expect(entry.package, isNotEmpty);
      expect(entry.displayName, isNotEmpty);
    }
  });
}
