import 'package:privacy_ledger/database/sdk_database.dart';
import 'package:privacy_ledger/generators/policy_summary_generator.dart';
import 'package:test/test.dart';

void main() {
  test('mentions each distinct data type and groups by purpose', () async {
    final db = await SdkDatabase.load();
    final sdks = [
      db.lookup('google_mobile_ads')!,
      db.lookup('firebase_core')!,
      db.lookup('purchases_flutter')!,
    ];

    final types = <String>{};
    for (final sdk in sdks) {
      for (final item in sdk.dataCollected) {
        types.add(item.type);
      }
    }

    final text = PolicySummaryGenerator().generate(sdks);

    // Each distinct type appears in the machine-readable footer at least once.
    for (final type in types) {
      expect(text, contains(type), reason: 'missing data type $type');
    }

    // Grouped by purpose language, not a laundry list of SDK brands.
    expect(text.toLowerCase(), contains('advertising'));
    expect(text.toLowerCase(), contains('analytics'));
    expect(text.toLowerCase(), contains('app functionality'));

    // SDK display names should not be repeated redundantly as the structure.
    final admobCount = 'Google AdMob'.allMatches(text).length;
    final revenueCatCount = 'RevenueCat'.allMatches(text).length;
    expect(admobCount, lessThanOrEqualTo(1));
    expect(revenueCatCount, lessThanOrEqualTo(1));
  });
}
