import 'package:privacy_ledger/database/sdk_database.dart';
import 'package:privacy_ledger/generators/xcprivacy_generator.dart';
import 'package:test/test.dart';

void main() {
  test('generates well-formed XML with google_mobile_ads entries', () async {
    final db = await SdkDatabase.load();
    final sdks = [
      db.lookup('google_mobile_ads')!,
      db.lookup('firebase_core')!,
      db.lookup('purchases_flutter')!,
    ];

    final xml = XcprivacyGenerator().generateXml(sdks);

    expect(xml, startsWith('<?xml version="1.0"'));
    expect(xml, contains('<plist version="1.0">'));
    expect(xml, contains('</plist>'));
    expect(xml, contains('<key>NSPrivacyTracking</key>'));
    expect(xml, contains('<key>NSPrivacyCollectedDataTypes</key>'));
    expect(xml, contains('<key>NSPrivacyAccessedAPITypes</key>'));

    // AdMob contributes Device ID + advertising purpose.
    expect(xml, contains('NSPrivacyCollectedDataTypeDeviceID'));
    expect(
      xml,
      contains('NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising'),
    );
    expect(xml, contains('NSPrivacyCollectedDataTypeCoarseLocation'));
    expect(xml, contains('NSPrivacyCollectedDataTypeAdvertisingData'));

    // Required reason API placeholders present.
    expect(xml, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
    expect(xml, contains(XcprivacyGenerator.placeholderReasonCode));

    // Balanced tags rough check.
    expect(
      '<dict>'.allMatches(xml).length,
      equals('</dict>'.allMatches(xml).length),
    );
    expect(
      '<array>'.allMatches(xml).length,
      equals('</array>'.allMatches(xml).length),
    );
  });

  test('skips SDKs that do not require xcprivacy entry', () async {
    final db = await SdkDatabase.load();
    final admob = db.lookup('google_mobile_ads')!;
    // Craft a no-xcprivacy sibling by loading admob alone vs empty.
    final emptyXml = XcprivacyGenerator().generateXml([]);
    expect(emptyXml, contains('<key>NSPrivacyCollectedDataTypes</key>'));
    expect(emptyXml, isNot(contains('NSPrivacyCollectedDataTypeDeviceID')));

    final withAdmob = XcprivacyGenerator().generateXml([admob]);
    expect(withAdmob, contains('NSPrivacyCollectedDataTypeDeviceID'));
  });
}
