import 'dart:io';
import 'dart:isolate';

import 'package:privacy_ledger/models/sdk_entry.dart';
import 'package:yaml/yaml.dart';

/// Loads bundled SDK data-collection YAML plus optional per-project overrides.
class SdkDatabase {
  final Map<String, SdkEntry> _entries;

  SdkDatabase._(this._entries);

  /// All loaded entries (bundled + overrides), keyed by package name.
  Map<String, SdkEntry> get entries => Map.unmodifiable(_entries);

  SdkEntry? lookup(String packageName) => _entries[packageName];

  /// Packages in [scannedPackages] with no database entry and no override.
  List<String> unknownPackages(List<String> scannedPackages) {
    return scannedPackages.where((name) => !_entries.containsKey(name)).toList()
      ..sort();
  }

  /// Loads all `*.yaml` files from the bundled sdk_data directory, then applies
  /// an optional project override file. Overrides win on conflict.
  static Future<SdkDatabase> load({
    Directory? sdkDataDir,
    File? overridesFile,
  }) async {
    final dir = sdkDataDir ?? await resolveBundledSdkDataDir();
    final entries = <String, SdkEntry>{};

    if (!dir.existsSync()) {
      throw StateError('SDK data directory not found: ${dir.path}');
    }

    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final entry = _parseEntryFile(file);
      entries[entry.package] = entry;
    }

    if (overridesFile != null && overridesFile.existsSync()) {
      _applyOverrides(entries, overridesFile);
    }

    return SdkDatabase._(entries);
  }

  /// Resolves `package:privacy_ledger/database/sdk_data/` on disk.
  static Future<Directory> resolveBundledSdkDataDir() async {
    final resolved = await Isolate.resolvePackageUri(
      Uri.parse('package:privacy_ledger/database/sdk_data/.gitkeep'),
    );
    if (resolved == null) {
      throw StateError(
        'Could not resolve package:privacy_ledger/database/sdk_data/. '
        'Is the package activated / on the package path?',
      );
    }
    return Directory.fromUri(resolved.resolve('.'));
  }

  static SdkEntry _parseEntryFile(File file) {
    final yaml = loadYaml(file.readAsStringSync());
    if (yaml is! YamlMap) {
      throw FormatException('SDK YAML is not a map: ${file.path}');
    }
    return SdkEntry.fromYaml(yaml);
  }

  /// Override file shape:
  /// ```yaml
  /// packages:
  ///   - package: foo
  ///     display_name: ...
  ///     ...
  /// ```
  /// A top-level YAML list of entries is also accepted.
  static void _applyOverrides(Map<String, SdkEntry> entries, File file) {
    final yaml = loadYaml(file.readAsStringSync());
    final List<dynamic> packageMaps;

    if (yaml is YamlMap && yaml['packages'] is YamlList) {
      packageMaps = List<dynamic>.from(yaml['packages'] as YamlList);
    } else if (yaml is YamlList) {
      packageMaps = List<dynamic>.from(yaml);
    } else {
      throw FormatException(
        'Override file must be a list of SDK entries, or a map with a '
        '`packages:` list: ${file.path}',
      );
    }

    for (final item in packageMaps) {
      if (item is! YamlMap) {
        throw FormatException(
          'Each override entry must be a YAML map: ${file.path}',
        );
      }
      final override = SdkEntry.fromYaml(item);
      // Overrides win entirely on conflict (full entry replacement).
      entries[override.package] = override;
    }
  }
}
