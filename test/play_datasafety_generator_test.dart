import 'package:privacy_ledger/database/sdk_database.dart';
import 'package:privacy_ledger/generators/play_datasafety_generator.dart';
import 'package:test/test.dart';

void main() {
  test('deduplicates device_id when two SDKs both collect it', () async {
    final db = await SdkDatabase.load();
    final sdks = [
      db.lookup('google_mobile_ads')!,
      db.lookup('firebase_core')!,
      db.lookup('purchases_flutter')!,
    ];

    final rows = PlayDatasafetyGenerator().buildRows(sdks);
    final deviceIdRows = rows.where((r) => r.dataType == 'device_id').toList();

    expect(deviceIdRows, hasLength(1));
    expect(deviceIdRows.single.collectedBySdks.length, greaterThanOrEqualTo(2));
    expect(
      deviceIdRows.single.collectedBySdks,
      containsAll(['Google AdMob', 'Firebase Core (Analytics + Crashlytics)']),
    );
    expect(deviceIdRows.single.sharedWithThirdParties, isTrue);
  });

  test('markdown includes Play Console purpose categories', () async {
    final db = await SdkDatabase.load();
    final md = PlayDatasafetyGenerator().generateMarkdown([
      db.lookup('google_mobile_ads')!,
      db.lookup('firebase_core')!,
      db.lookup('purchases_flutter')!,
    ]);

    expect(md, contains('Advertising or marketing'));
    expect(md, contains('Analytics'));
    expect(md, contains('App functionality'));
    expect(md, contains('Collected by multiple SDKs:'));
    expect(md, contains('purchase_history'));
  });
}
