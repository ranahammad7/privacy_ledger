import 'dart:io';

import 'package:privacy_ledger/scanner/pubspec_scanner.dart';
import 'package:test/test.dart';

void main() {
  late Directory fixtureDir;
  final scanner = PubspecScanner();

  setUp(() {
    // Build a temp project root pointing at the fixture files.
    fixtureDir = Directory.systemTemp.createTempSync('privacy_ledger_scan_');
    final fixtures = Directory('test/fixtures');
    File(
      '${fixtureDir.path}${Platform.pathSeparator}pubspec.yaml',
    ).writeAsStringSync(
      File(
        '${fixtures.path}${Platform.pathSeparator}sample_pubspec.yaml',
      ).readAsStringSync(),
    );
    File(
      '${fixtureDir.path}${Platform.pathSeparator}pubspec.lock',
    ).writeAsStringSync(
      File(
        '${fixtures.path}${Platform.pathSeparator}sample_pubspec.lock',
      ).readAsStringSync(),
    );
  });

  tearDown(() {
    if (fixtureDir.existsSync()) {
      fixtureDir.deleteSync(recursive: true);
    }
  });

  test('returns direct and transitive deps with resolved versions', () {
    final deps = scanner.scan(fixtureDir.path);

    final byName = {for (final d in deps) d.packageName: d};

    expect(byName['google_mobile_ads']?.resolvedVersion, '5.1.0');
    expect(byName['google_mobile_ads']?.isDirect, isTrue);

    expect(byName['firebase_core']?.resolvedVersion, '3.4.0');
    expect(byName['firebase_core']?.isDirect, isTrue);

    expect(byName['purchases_flutter']?.resolvedVersion, '8.1.0');
    expect(byName['purchases_flutter']?.isDirect, isTrue);

    expect(byName['http']?.isDirect, isTrue);

    // Transitive only.
    expect(byName['http_parser']?.resolvedVersion, '4.0.2');
    expect(byName['http_parser']?.isDirect, isFalse);
    expect(byName['firebase_core_platform_interface']?.isDirect, isFalse);

    // SDK packages excluded.
    expect(byName.containsKey('flutter'), isFalse);
  });

  test('throws a clear error when pubspec.lock is missing', () {
    File(
      '${fixtureDir.path}${Platform.pathSeparator}pubspec.lock',
    ).deleteSync();

    expect(
      () => scanner.scan(fixtureDir.path),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('dart pub get'),
        ),
      ),
    );
  });

  test('throws when pubspec.yaml is missing', () {
    File(
      '${fixtureDir.path}${Platform.pathSeparator}pubspec.yaml',
    ).deleteSync();

    expect(() => scanner.scan(fixtureDir.path), throwsA(isA<StateError>()));
  });
}
