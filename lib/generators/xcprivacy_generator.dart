import 'dart:io';

import 'package:privacy_ledger/models/sdk_entry.dart';
import 'package:privacy_ledger/scanner/pubspec_scanner.dart';

/// Generates an Apple `PrivacyInfo.xcprivacy` plist from matched SDK entries.
///
/// Schema keys follow Apple's Privacy Manifest documentation:
/// https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
class XcprivacyGenerator {
  /// Maps our database `type` strings to Apple's NSPrivacyCollectedDataType values.
  static const Map<String, String> dataTypeToApple = {
    'device_id': 'NSPrivacyCollectedDataTypeDeviceID',
    'user_id': 'NSPrivacyCollectedDataTypeUserID',
    'approximate_location': 'NSPrivacyCollectedDataTypeCoarseLocation',
    'coarse_location': 'NSPrivacyCollectedDataTypeCoarseLocation',
    'precise_location': 'NSPrivacyCollectedDataTypePreciseLocation',
    'purchase_history': 'NSPrivacyCollectedDataTypePurchaseHistory',
    'payment_info': 'NSPrivacyCollectedDataTypePaymentInfo',
    'crash_data': 'NSPrivacyCollectedDataTypeCrashData',
    'performance_data': 'NSPrivacyCollectedDataTypePerformanceData',
    'diagnostics': 'NSPrivacyCollectedDataTypeCrashData',
    'advertising_data': 'NSPrivacyCollectedDataTypeAdvertisingData',
    'product_interaction': 'NSPrivacyCollectedDataTypeProductInteraction',
    'email': 'NSPrivacyCollectedDataTypeEmailAddress',
    'name': 'NSPrivacyCollectedDataTypeName',
    'phone_number': 'NSPrivacyCollectedDataTypePhoneNumber',
    'photos': 'NSPrivacyCollectedDataTypePhotosorVideos',
    'videos': 'NSPrivacyCollectedDataTypePhotosorVideos',
    'files_and_docs': 'NSPrivacyCollectedDataTypeOtherUserContent',
    'biometric': 'NSPrivacyCollectedDataTypeOtherDataTypes',
  };

  /// Maps our `purpose` strings to Apple's NSPrivacyCollectedDataTypePurposes.
  static const Map<String, String> purposeToApple = {
    'advertising': 'NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising',
    'analytics': 'NSPrivacyCollectedDataTypePurposeAnalytics',
    'app_functionality': 'NSPrivacyCollectedDataTypePurposeAppFunctionality',
    'fraud_prevention': 'NSPrivacyCollectedDataTypePurposeAppFunctionality',
    'product_personalization':
        'NSPrivacyCollectedDataTypePurposeProductPersonalization',
    'developer_advertising':
        'NSPrivacyCollectedDataTypePurposeDeveloperAdvertising',
    'other': 'NSPrivacyCollectedDataTypePurposeOther',
  };

  /// Maps short API category names from YAML to Apple's NSPrivacyAccessedAPIType.
  static const Map<String, String> apiCategoryToApple = {
    'UserDefaults': 'NSPrivacyAccessedAPICategoryUserDefaults',
    'FileTimestamp': 'NSPrivacyAccessedAPICategoryFileTimestamp',
    'DiskSpace': 'NSPrivacyAccessedAPICategoryDiskSpace',
    'SystemBootTime': 'NSPrivacyAccessedAPICategorySystemBootTime',
    'ActiveKeyboards': 'NSPrivacyAccessedAPICategoryActiveKeyboards',
  };

  /// HUMAN-VERIFICATION POINT:
  /// Reason codes must be chosen from Apple's official approved list for each
  /// API category (e.g. CA92.1, C617.1, 35F9.1). Do NOT trust this placeholder
  /// in a real App Store submission — replace after verifying against:
  /// https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api
  static const String placeholderReasonCode = 'PLACEHOLDER_VERIFY_WITH_APPLE';

  /// Builds plist XML for [sdks], writing only entries where
  /// [SdkEntry.requiresXcprivacyEntry] is true.
  ///
  /// Apple's PrivacyInfo.xcprivacy schema does **not** include app name,
  /// version, or bundle ID — those belong in Info.plist / App Store Connect.
  /// When [project] is provided, identity is stamped in XML comments only
  /// (ignored by Apple parsers, useful for humans reviewing the draft).
  String generateXml(List<SdkEntry> sdks, {ProjectInfo? project}) {
    final relevant = sdks.where((e) => e.requiresXcprivacyEntry).toList();

    // Deduplicate collected data types (keyed by Apple type string).
    // If any contributing item is shared with third parties, mark tracking.
    final collected = <String, _CollectedAgg>{};
    final accessedApis = <String>{};

    var anyTracking = false;

    for (final sdk in relevant) {
      for (final item in sdk.dataCollected) {
        final appleType =
            dataTypeToApple[item.type] ??
            'NSPrivacyCollectedDataTypeOtherDataTypes';
        final applePurpose =
            purposeToApple[item.purpose] ??
            'NSPrivacyCollectedDataTypePurposeOther';
        final tracking =
            item.sharedWithThirdParties &&
            (item.purpose == 'advertising' ||
                item.purpose == 'developer_advertising');
        if (tracking) anyTracking = true;

        collected.putIfAbsent(
          appleType,
          () => _CollectedAgg(appleType: appleType),
        );
        final agg = collected[appleType]!;
        agg.purposes.add(applePurpose);
        if (tracking) agg.tracking = true;
        // If any contributing item is linked to identity, the merged type is.
        if (item.linkedToIdentity) {
          agg.linked = true;
        }
      }

      for (final api in sdk.requiredReasonApis) {
        accessedApis.add(apiCategoryToApple[api] ?? api);
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
      '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
    );
    if (project != null) {
      buffer.writeln(
        '<!-- Generated by privacy_ledger for '
        '${_escapeComment(project.name)} ${_escapeComment(project.version)} -->',
      );
      buffer.writeln(
        '<!-- Project: ${_escapeComment(project.name)} -->',
      );
      buffer.writeln(
        '<!-- Version: ${_escapeComment(project.version)} -->',
      );
      if (project.description != null && project.description!.trim().isNotEmpty) {
        buffer.writeln(
          '<!-- Description: ${_escapeComment(project.description!.trim())} -->',
        );
      }
      buffer.writeln(
        '<!-- Source: ${_escapeComment(project.projectPath)} -->',
      );
      buffer.writeln(
        '<!-- NOTE: App name/version are NOT Apple PrivacyInfo keys. '
        'They are documentation only. Bundle ID / CFBundle* live in Info.plist. -->',
      );
    }
    buffer.writeln('<plist version="1.0">');
    buffer.writeln('<dict>');

    // NSPrivacyTracking
    buffer.writeln('\t<key>NSPrivacyTracking</key>');
    buffer.writeln(anyTracking ? '\t<true/>' : '\t<false/>');

    // Empty tracking domains — developer must fill if NSPrivacyTracking is true.
    buffer.writeln('\t<key>NSPrivacyTrackingDomains</key>');
    buffer.writeln('\t<array/>');

    // NSPrivacyCollectedDataTypes
    buffer.writeln('\t<key>NSPrivacyCollectedDataTypes</key>');
    buffer.writeln('\t<array>');
    final sortedTypes = collected.keys.toList()..sort();
    for (final key in sortedTypes) {
      final agg = collected[key]!;
      buffer.writeln('\t\t<dict>');
      buffer.writeln('\t\t\t<key>NSPrivacyCollectedDataType</key>');
      buffer.writeln('\t\t\t<string>${_escape(agg.appleType)}</string>');
      buffer.writeln('\t\t\t<key>NSPrivacyCollectedDataTypeLinked</key>');
      buffer.writeln(agg.linked ? '\t\t\t<true/>' : '\t\t\t<false/>');
      buffer.writeln('\t\t\t<key>NSPrivacyCollectedDataTypeTracking</key>');
      buffer.writeln(agg.tracking ? '\t\t\t<true/>' : '\t\t\t<false/>');
      buffer.writeln('\t\t\t<key>NSPrivacyCollectedDataTypePurposes</key>');
      buffer.writeln('\t\t\t<array>');
      final purposes = agg.purposes.toList()..sort();
      for (final p in purposes) {
        buffer.writeln('\t\t\t\t<string>${_escape(p)}</string>');
      }
      buffer.writeln('\t\t\t</array>');
      buffer.writeln('\t\t</dict>');
    }
    buffer.writeln('\t</array>');

    // NSPrivacyAccessedAPITypes
    // HUMAN-VERIFICATION: reason codes are placeholders — see placeholderReasonCode.
    buffer.writeln('\t<key>NSPrivacyAccessedAPITypes</key>');
    buffer.writeln('\t<array>');
    final sortedApis = accessedApis.toList()..sort();
    for (final apiType in sortedApis) {
      buffer.writeln('\t\t<dict>');
      buffer.writeln('\t\t\t<key>NSPrivacyAccessedAPIType</key>');
      buffer.writeln('\t\t\t<string>${_escape(apiType)}</string>');
      buffer.writeln('\t\t\t<key>NSPrivacyAccessedAPITypeReasons</key>');
      buffer.writeln('\t\t\t<array>');
      // Placeholder — must be replaced with an Apple-approved reason code.
      buffer.writeln(
        '\t\t\t\t<string>${_escape(placeholderReasonCode)}</string>',
      );
      buffer.writeln('\t\t\t</array>');
      buffer.writeln('\t\t</dict>');
    }
    buffer.writeln('\t</array>');

    buffer.writeln('</dict>');
    buffer.writeln('</plist>');
    return buffer.toString();
  }

  /// Writes [generateXml] output to [outputPath].
  void writeToFile(
    List<SdkEntry> sdks,
    String outputPath, {
    ProjectInfo? project,
  }) {
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(generateXml(sdks, project: project));
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _escapeComment(String value) {
    // XML comments cannot contain "--".
    return value.replaceAll('--', '—');
  }
}

class _CollectedAgg {
  final String appleType;
  final Set<String> purposes = {};
  bool linked = false;
  bool tracking = false;

  _CollectedAgg({required this.appleType});
}
