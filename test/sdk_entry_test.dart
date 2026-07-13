import 'package:privacy_ledger/models/sdk_entry.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('SdkEntry.fromYaml', () {
    test('parses a fully populated entry', () {
      final yaml =
          loadYaml('''
package: google_mobile_ads
display_name: Google AdMob
data_collected:
  - type: device_id
    purpose: advertising
    shared_with_third_parties: true
    optional: false
  - type: approximate_location
    purpose: advertising
    shared_with_third_parties: true
    optional: true
encrypted_in_transit: true
user_can_request_deletion: false
requires_xcprivacy_entry: true
required_reason_apis: [UserDefaults]
notes: "Country-gating ads does not change declarations."
''')
              as YamlMap;

      final entry = SdkEntry.fromYaml(yaml);

      expect(entry.package, 'google_mobile_ads');
      expect(entry.displayName, 'Google AdMob');
      expect(entry.dataCollected, hasLength(2));
      expect(entry.dataCollected[0].type, 'device_id');
      expect(entry.dataCollected[0].purpose, 'advertising');
      expect(entry.dataCollected[0].sharedWithThirdParties, isTrue);
      expect(entry.dataCollected[0].optional, isFalse);
      expect(entry.dataCollected[0].linkedToIdentity, isTrue); // default
      expect(entry.dataCollected[1].type, 'approximate_location');
      expect(entry.dataCollected[1].optional, isTrue);
      expect(entry.dataCollected[1].linkedToIdentity, isTrue); // default
      expect(entry.encryptedInTransit, isTrue);
      expect(entry.userCanRequestDeletion, isFalse);
      expect(entry.requiresXcprivacyEntry, isTrue);
      expect(entry.requiredReasonApis, ['UserDefaults']);
      expect(entry.notes, 'Country-gating ads does not change declarations.');
    });

    test('parses an entry with optional fields missing', () {
      final yaml =
          loadYaml('''
package: some_sdk
display_name: Some SDK
data_collected:
  - type: diagnostics
    purpose: analytics
    shared_with_third_parties: false
    optional: false
encrypted_in_transit: true
user_can_request_deletion: true
requires_xcprivacy_entry: false
''')
              as YamlMap;

      final entry = SdkEntry.fromYaml(yaml);

      expect(entry.package, 'some_sdk');
      expect(entry.displayName, 'Some SDK');
      expect(entry.dataCollected, hasLength(1));
      expect(entry.requiredReasonApis, isEmpty);
      expect(entry.notes, isNull);
      expect(entry.requiresXcprivacyEntry, isFalse);
    });
  });

  group('DataCollectionItem.fromYaml', () {
    test('parses a single item', () {
      final yaml =
          loadYaml('''
type: email
purpose: app_functionality
shared_with_third_parties: false
optional: true
''')
              as YamlMap;

      final item = DataCollectionItem.fromYaml(yaml);

      expect(item.type, 'email');
      expect(item.purpose, 'app_functionality');
      expect(item.sharedWithThirdParties, isFalse);
      expect(item.optional, isTrue);
      expect(item.linkedToIdentity, isTrue);
    });

    test('parses linked_to_identity false when explicit', () {
      final yaml =
          loadYaml('''
type: approximate_location
purpose: fraud_prevention
shared_with_third_parties: true
optional: true
linked_to_identity: false
''')
              as YamlMap;

      final item = DataCollectionItem.fromYaml(yaml);
      expect(item.linkedToIdentity, isFalse);
    });
  });
}
