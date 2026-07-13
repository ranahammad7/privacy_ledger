import 'package:privacy_ledger/database/sdk_database.dart';
import 'package:privacy_ledger/generators/xcprivacy_generator.dart';
import 'package:privacy_ledger/scanner/pubspec_scanner.dart';
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

  test('Stripe Name and Payment Info are Linked when YAML says so', () async {
    final db = await SdkDatabase.load();
    final stripe = db.lookup('flutter_stripe')!;
    final xml = XcprivacyGenerator().generateXml([stripe]);

    expect(_isLinked(xml, 'NSPrivacyCollectedDataTypeName'), isTrue);
    expect(_isLinked(xml, 'NSPrivacyCollectedDataTypePaymentInfo'), isTrue);
    expect(_isLinked(xml, 'NSPrivacyCollectedDataTypePurchaseHistory'), isTrue);
    expect(_isLinked(xml, 'NSPrivacyCollectedDataTypeEmailAddress'), isTrue);
    expect(_isLinked(xml, 'NSPrivacyCollectedDataTypeDeviceID'), isTrue);
    // Explicit linked_to_identity: false on approximate_location.
    expect(_isLinked(xml, 'NSPrivacyCollectedDataTypeCoarseLocation'), isFalse);
  });

  test('XML comments include project name and version', () async {
    final db = await SdkDatabase.load();
    final xml = XcprivacyGenerator().generateXml(
      [db.lookup('flutter_stripe')!],
      project: const ProjectInfo(
        name: 'nsol_customer_portal',
        version: '1.0.0+1',
        projectPath: r'D:\nsol_customer_portal',
        description: 'NSOL Customer Portal',
      ),
    );

    expect(xml, contains('<!-- Project: nsol_customer_portal -->'));
    expect(xml, contains('<!-- Version: 1.0.0+1 -->'));
    expect(xml, contains('<!-- Description: NSOL Customer Portal -->'));
    // Still must not invent fake Apple keys for app identity.
    expect(xml, isNot(contains('<key>CFBundleName</key>')));
    expect(xml, isNot(contains('<key>AppName</key>')));
  });
}

/// Returns the Linked bool for the first dict whose data type is [appleType].
bool _isLinked(String xml, String appleType) {
  final typeMarker =
      '<key>NSPrivacyCollectedDataType</key>\n'
      '\t\t\t<string>$appleType</string>';
  final typeIndex = xml.indexOf(typeMarker);
  expect(typeIndex, isNonNegative, reason: 'missing $appleType in XML');
  final linkedKey = xml.indexOf(
    '<key>NSPrivacyCollectedDataTypeLinked</key>',
    typeIndex,
  );
  expect(linkedKey, isNonNegative);
  final after = xml.substring(linkedKey, linkedKey + 80);
  if (after.contains('<true/>')) return true;
  if (after.contains('<false/>')) return false;
  fail('Could not parse Linked for $appleType');
}
