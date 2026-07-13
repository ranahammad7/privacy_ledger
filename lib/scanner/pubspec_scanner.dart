import 'dart:io';

import 'package:yaml/yaml.dart';

/// A single dependency discovered from pubspec.yaml / pubspec.lock.
class ScannedDependency {
  final String packageName;
  final String resolvedVersion;
  final bool isDirect;

  const ScannedDependency({
    required this.packageName,
    required this.resolvedVersion,
    required this.isDirect,
  });

  @override
  String toString() =>
      'ScannedDependency($packageName@$resolvedVersion, isDirect: $isDirect)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedDependency &&
          packageName == other.packageName &&
          resolvedVersion == other.resolvedVersion &&
          isDirect == other.isDirect;

  @override
  int get hashCode => Object.hash(packageName, resolvedVersion, isDirect);
}

/// Parses pubspec.yaml and pubspec.lock to produce a normalized dependency list.
class PubspecScanner {
  /// Scans [projectRoot] for direct and transitive dependencies.
  ///
  /// Throws [StateError] if pubspec.yaml is missing, or if pubspec.lock is
  /// missing (telling the user to run `dart pub get` first).
  List<ScannedDependency> scan(String projectRoot) {
    final root = Directory(projectRoot);
    final pubspecFile = File(
      '${root.path}${Platform.pathSeparator}pubspec.yaml',
    );
    final lockFile = File('${root.path}${Platform.pathSeparator}pubspec.lock');

    if (!pubspecFile.existsSync()) {
      throw StateError(
        'No pubspec.yaml found at ${pubspecFile.path}. '
        'Pass the root of a Dart/Flutter project.',
      );
    }

    if (!lockFile.existsSync()) {
      throw StateError(
        'No pubspec.lock found at ${lockFile.path}. '
        'Run `dart pub get` (or `flutter pub get`) in the project first.',
      );
    }

    final directNames = _parseDirectDependencies(
      pubspecFile.readAsStringSync(),
    );
    final resolved = _parseLockFile(lockFile.readAsStringSync());

    final results = <ScannedDependency>[];
    for (final entry in resolved.entries) {
      results.add(
        ScannedDependency(
          packageName: entry.key,
          resolvedVersion: entry.value,
          isDirect: directNames.contains(entry.key),
        ),
      );
    }

    results.sort((a, b) => a.packageName.compareTo(b.packageName));
    return results;
  }

  /// Extracts package names from the `dependencies:` section of pubspec.yaml.
  ///
  /// Dev/override dependencies are ignored — they are not shipped in the app.
  Set<String> _parseDirectDependencies(String contents) {
    final yaml = loadYaml(contents);
    if (yaml is! YamlMap) {
      throw StateError('pubspec.yaml is not a valid YAML map.');
    }

    final deps = yaml['dependencies'];
    if (deps == null) return {};
    if (deps is! YamlMap) {
      throw StateError('pubspec.yaml dependencies section is not a map.');
    }

    final names = <String>{};
    for (final key in deps.keys) {
      final name = key.toString();
      // The package's own SDK constraint entry is "flutter"/"flutter_test"
      // under dependencies sometimes; we still include them if present —
      // the database simply won't match them.
      if (name == 'flutter' ||
          name == 'flutter_localizations' ||
          name == 'sdk') {
        continue;
      }
      names.add(name);
    }
    return names;
  }

  /// Parses pubspec.lock packages → resolved version strings.
  Map<String, String> _parseLockFile(String contents) {
    final yaml = loadYaml(contents);
    if (yaml is! YamlMap) {
      throw StateError('pubspec.lock is not a valid YAML map.');
    }

    final packages = yaml['packages'];
    if (packages == null) return {};
    if (packages is! YamlMap) {
      throw StateError('pubspec.lock packages section is not a map.');
    }

    final result = <String, String>{};
    for (final entry in packages.entries) {
      final name = entry.key.toString();
      final info = entry.value;
      if (info is! YamlMap) continue;

      // Skip SDK packages (Dart/Flutter SDK itself) — not pub packages.
      final source = info['source']?.toString();
      if (source == 'sdk') continue;

      final version = info['version']?.toString();
      if (version == null) continue;

      result[name] = version;
    }
    return result;
  }
}
