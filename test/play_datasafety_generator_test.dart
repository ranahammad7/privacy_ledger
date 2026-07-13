import 'package:privacy_ledger/database/sdk_database.dart';
import 'package:privacy_ledger/generators/play_datasafety_generator.dart';
import 'package:privacy_ledger/scanner/pubspec_scanner.dart';
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

  test('purpose line is joined without Dart list brackets', () async {
    final db = await SdkDatabase.load();
    final md = PlayDatasafetyGenerator().generateMarkdown([
      db.lookup('flutter_stripe')!,
    ]);

    expect(md, contains('- **Purpose:** App functionality'));
    expect(
      md,
      contains('- **Purpose:** Fraud prevention, security, and compliance'),
    );
    expect(md, isNot(contains('**Purpose:** [')));
  });

  test('markdown includes project name and version when provided', () async {
    final db = await SdkDatabase.load();
    final md = PlayDatasafetyGenerator().generateMarkdown(
      [db.lookup('flutter_stripe')!],
      project: const ProjectInfo(
        name: 'nsol_customer_portal',
        version: '1.0.0+1',
        projectPath: r'D:\nsol_customer_portal',
        description: 'NSOL Customer Portal',
      ),
    );

    expect(md, contains('nsol_customer_portal'));
    expect(md, contains('1.0.0+1'));
    expect(md, contains('NSOL Customer Portal'));
  });
}
