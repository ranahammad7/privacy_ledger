import 'package:yaml/yaml.dart';

/// A single data type collected by an SDK, matching the YAML shape in the PRD.
class DataCollectionItem {
  final String type;
  final String purpose;
  final bool sharedWithThirdParties;
  final bool optional;

  const DataCollectionItem({
    required this.type,
    required this.purpose,
    required this.sharedWithThirdParties,
    required this.optional,
  });

  factory DataCollectionItem.fromYaml(YamlMap map) {
    return DataCollectionItem(
      type: map['type'] as String,
      purpose: map['purpose'] as String,
      sharedWithThirdParties: map['shared_with_third_parties'] as bool,
      optional: map['optional'] as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataCollectionItem &&
          type == other.type &&
          purpose == other.purpose &&
          sharedWithThirdParties == other.sharedWithThirdParties &&
          optional == other.optional;

  @override
  int get hashCode =>
      Object.hash(type, purpose, sharedWithThirdParties, optional);
}

/// An SDK database entry describing a known Flutter package's data practices.
class SdkEntry {
  final String package;
  final String displayName;
  final List<DataCollectionItem> dataCollected;
  final bool encryptedInTransit;
  final bool userCanRequestDeletion;
  final bool requiresXcprivacyEntry;
  final List<String> requiredReasonApis;
  final String? notes;

  const SdkEntry({
    required this.package,
    required this.displayName,
    required this.dataCollected,
    required this.encryptedInTransit,
    required this.userCanRequestDeletion,
    required this.requiresXcprivacyEntry,
    required this.requiredReasonApis,
    this.notes,
  });

  factory SdkEntry.fromYaml(YamlMap map) {
    final rawCollected = map['data_collected'] as YamlList?;
    final dataCollected = rawCollected == null
        ? <DataCollectionItem>[]
        : rawCollected
              .map((e) => DataCollectionItem.fromYaml(e as YamlMap))
              .toList();

    final rawApis = map['required_reason_apis'] as YamlList?;
    final requiredReasonApis = rawApis == null
        ? <String>[]
        : rawApis.map((e) => e.toString()).toList();

    return SdkEntry(
      package: map['package'] as String,
      displayName: map['display_name'] as String,
      dataCollected: dataCollected,
      encryptedInTransit: map['encrypted_in_transit'] as bool? ?? false,
      userCanRequestDeletion:
          map['user_can_request_deletion'] as bool? ?? false,
      requiresXcprivacyEntry: map['requires_xcprivacy_entry'] as bool? ?? false,
      requiredReasonApis: requiredReasonApis,
      notes: map['notes'] as String?,
    );
  }

  /// Returns a copy with any non-null override fields applied.
  SdkEntry merge(SdkEntry override) {
    return SdkEntry(
      package: override.package,
      displayName: override.displayName,
      dataCollected: override.dataCollected.isNotEmpty
          ? override.dataCollected
          : dataCollected,
      encryptedInTransit: override.encryptedInTransit,
      userCanRequestDeletion: override.userCanRequestDeletion,
      requiresXcprivacyEntry: override.requiresXcprivacyEntry,
      requiredReasonApis: override.requiredReasonApis.isNotEmpty
          ? override.requiredReasonApis
          : requiredReasonApis,
      notes: override.notes ?? notes,
    );
  }
}
