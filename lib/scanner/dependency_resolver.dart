/// Resolves and normalizes dependency lists from [PubspecScanner] results.
///
/// Currently a thin helper; expand when native Android/iOS scanning lands.
library;

import 'pubspec_scanner.dart';

class DependencyResolver {
  /// Returns package names only, sorted alphabetically.
  List<String> packageNames(List<ScannedDependency> deps) {
    final names = deps.map((d) => d.packageName).toList()..sort();
    return names;
  }

  /// Direct dependencies only.
  List<ScannedDependency> directOnly(List<ScannedDependency> deps) =>
      deps.where((d) => d.isDirect).toList();
}
