import 'dart:io';

import 'package:args/args.dart';
import 'package:privacy_ledger/database/sdk_database.dart';
import 'package:privacy_ledger/generators/play_datasafety_generator.dart';
import 'package:privacy_ledger/generators/policy_summary_generator.dart';
import 'package:privacy_ledger/generators/xcprivacy_generator.dart';
import 'package:privacy_ledger/models/sdk_entry.dart';
import 'package:privacy_ledger/scanner/pubspec_scanner.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand(
      'scan',
      ArgParser()
        ..addOption(
          'project',
          abbr: 'p',
          help: 'Path to the Flutter/Dart project root',
          mandatory: true,
        )
        ..addOption(
          'output',
          abbr: 'o',
          help: 'Directory to write generated disclosure files',
          mandatory: true,
        )
        ..addFlag(
          'dry-run',
          help: 'Print the summary table only; do not write files',
          defaultsTo: false,
        ),
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (results['help'] == true || results.command == null) {
    _printUsage(parser);
    return;
  }

  final command = results.command!;
  if (command.name != 'scan') {
    stderr.writeln('Unknown command: ${command.name}');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  final projectPath = command['project'] as String;
  final outputPath = command['output'] as String;
  final dryRun = command['dry-run'] as bool;

  try {
    await _runScan(
      projectPath: projectPath,
      outputPath: outputPath,
      dryRun: dryRun,
    );
  } catch (e, st) {
    stderr.writeln('Error: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}

Future<void> _runScan({
  required String projectPath,
  required String outputPath,
  required bool dryRun,
}) async {
  final scanner = PubspecScanner();
  final project = scanner.readProjectInfo(projectPath);
  final deps = scanner.scan(projectPath);

  stdout.writeln();
  stdout.writeln('App: ${project.name} @ ${project.version}');
  if (project.description != null && project.description!.trim().isNotEmpty) {
    stdout.writeln('  ${project.description!.trim()}');
  }

  final overrides = File(
    '$projectPath${Platform.pathSeparator}privacy_ledger.overrides.yaml',
  );
  final db = await SdkDatabase.load(
    overridesFile: overrides.existsSync() ? overrides : null,
  );

  final matched = <SdkEntry>[];
  final rows = <_SummaryRow>[];

  for (final dep in deps) {
    final entry = db.lookup(dep.packageName);
    if (entry != null) matched.add(entry);
    rows.add(
      _SummaryRow(
        packageName: dep.packageName,
        version: dep.resolvedVersion,
        isDirect: dep.isDirect,
        inDatabase: entry != null,
        requiresXcprivacy: entry?.requiresXcprivacyEntry ?? false,
      ),
    );
  }

  final unknown = db.unknownPackages(deps.map((d) => d.packageName).toList());
  final unknownDirect =
      deps
          .where((d) => d.isDirect && unknown.contains(d.packageName))
          .map((d) => d.packageName)
          .toList()
        ..sort();
  final unknownTransitiveCount = unknown.length - unknownDirect.length;

  _printSummaryTable(rows);

  stdout.writeln();
  stdout.writeln(
    'Matched SDKs in database: ${matched.length} '
    '(of ${deps.where((d) => d.isDirect).length} direct / '
    '${deps.length} total packages)',
  );

  if (unknownDirect.isNotEmpty) {
    stdout.writeln();
    stdout.writeln(
      '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!',
    );
    stdout.writeln(
      'WARNING: ${unknownDirect.length} DIRECT package(s) are NOT in the '
      'SDK database.',
    );
    stdout.writeln(
      'Research these before shipping. Add privacy_ledger.overrides.yaml '
      'or contribute entries.',
    );
    stdout.writeln(
      '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!',
    );
    for (final name in unknownDirect) {
      stdout.writeln('  - $name');
    }
  }

  if (unknownTransitiveCount > 0) {
    stdout.writeln();
    stdout.writeln(
      'Note: $unknownTransitiveCount transitive package(s) also lack '
      'database entries (usually fine for pure Dart helpers).',
    );
  }

  if (dryRun) {
    stdout.writeln();
    stdout.writeln(
      'Dry run — no files written. Re-run without --dry-run to generate.',
    );
    return;
  }

  final outDir = Directory(outputPath)..createSync(recursive: true);
  final sep = Platform.pathSeparator;

  final xcprivacyPath = '${outDir.path}${sep}PrivacyInfo.xcprivacy';
  XcprivacyGenerator().writeToFile(matched, xcprivacyPath, project: project);

  final playPath = '${outDir.path}${sep}play_data_safety.md';
  PlayDatasafetyGenerator().writeToFile(matched, playPath, project: project);

  final policyPath = '${outDir.path}${sep}policy_summary.md';
  PolicySummaryGenerator().writeToFile(matched, policyPath, project: project);

  stdout.writeln();
  stdout.writeln('Wrote:');
  stdout.writeln('  [OK] $xcprivacyPath');
  stdout.writeln('  [OK] $playPath');
  stdout.writeln('  [OK] $policyPath');
}

void _printSummaryTable(List<_SummaryRow> rows) {
  // Only show packages that are either in the database or direct deps —
  // printing every transitive package floods the console.
  final interesting = rows.where((r) => r.inDatabase || r.isDirect).toList()
    ..sort((a, b) {
      if (a.inDatabase != b.inDatabase) return a.inDatabase ? -1 : 1;
      return a.packageName.compareTo(b.packageName);
    });

  stdout.writeln();
  stdout.writeln(
    '${'Package'.padRight(36)} ${'Ver'.padRight(12)} '
    '${'Dir?'.padRight(5)} ${'DB?'.padRight(4)} Xcpriv?',
  );
  stdout.writeln('${'-' * 36} ${'-' * 12} ${'-' * 5} ${'-' * 4} -------');

  for (final row in interesting) {
    stdout.writeln(
      '${row.packageName.padRight(36)} '
      '${row.version.padRight(12)} '
      '${(row.isDirect ? 'Y' : 'N').padRight(5)} '
      '${(row.inDatabase ? 'Y' : 'N').padRight(4)} '
      '${row.requiresXcprivacy ? 'Y' : 'N'}',
    );
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln('privacy_ledger — Flutter privacy disclosure generator\n');
  stdout.writeln('Usage:');
  stdout.writeln(
    '  privacy_ledger scan --project <path> --output <dir> [--dry-run]',
  );
  stdout.writeln();
  stdout.writeln(parser.usage);
}

class _SummaryRow {
  final String packageName;
  final String version;
  final bool isDirect;
  final bool inDatabase;
  final bool requiresXcprivacy;

  _SummaryRow({
    required this.packageName,
    required this.version,
    required this.isDirect,
    required this.inDatabase,
    required this.requiresXcprivacy,
  });
}
