import 'dart:io';

import 'package:myteam/core/constants/app_constants.dart';
import 'package:myteam/core/services/updater/release_key_pin.dart';

void main(List<String> args) {
  if (args.length != 5) {
    stderr.writeln(
      'Usage: dart run tool/validate_qa_updater_build.dart '
      '<public-key-hex> <A-name> <A-code> <B-name> <B-code>',
    );
    exitCode = 64;
    return;
  }

  final publicKey = args[0];
  final buildNameA = args[1];
  final buildCodeA = int.tryParse(args[2]);
  final buildNameB = args[3];
  final buildCodeB = int.tryParse(args[4]);
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final baseVersion = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  final currentVersionName = baseVersion?.group(1);
  final currentBuildCode = int.tryParse(baseVersion?.group(2) ?? '');

  if (!_isSemver(buildNameA) || !_isSemver(buildNameB)) {
    stderr.writeln('QA build names must use numeric major.minor.patch format.');
    exitCode = 65;
    return;
  }
  if (buildCodeA == null ||
      buildCodeB == null ||
      currentBuildCode == null ||
      buildCodeA <= currentBuildCode ||
      buildCodeB <= buildCodeA ||
      buildCodeB > 2147483647 ||
      currentVersionName == null ||
      _compareVersions(buildNameA, currentVersionName) <= 0 ||
      _compareVersions(buildNameB, buildNameA) <= 0) {
    stderr.writeln(
      'QA version names and build codes must both progress monotonically from pubspec.yaml to A to B.',
    );
    exitCode = 65;
    return;
  }

  final androidBuild = File('android/app/build.gradle.kts').readAsStringSync();
  final qaWorkflow = File(
    '.github/workflows/qa-updater-build.yml',
  ).readAsStringSync();
  if (!androidBuild.contains('"qa" -> "com.example.myteam_video_app"') ||
      !androidBuild.contains('else -> "it.simogatti.myteam"') ||
      !androidBuild.contains('applicationId = androidApplicationId') ||
      !qaWorkflow.contains('MYTEAM_ANDROID_SIGNING_CHANNEL: qa') ||
      !qaWorkflow.contains('--dart-define=MYTEAM_UPDATER_QA=true') ||
      !qaWorkflow.contains("name='com.example.myteam_video_app'")) {
    stderr.writeln(
      'Android QA must retain its legacy test ID and production must use it.simogatti.myteam.',
    );
    exitCode = 65;
    return;
  }

  final windowsInstallerLines = File(
    'windows/installer/MyTeam-Setup.iss',
  ).readAsLinesSync();
  if (!windowsInstallerLines.contains(
        'AppId={{9B7E3E5C-62E8-4DA4-8FB7-F58552309AA2}',
      ) ||
      !windowsInstallerLines.contains(
        r'DefaultDirName={localappdata}\Programs\{#MyAppName}',
      ) ||
      !windowsInstallerLines.contains('CloseApplications=yes') ||
      !windowsInstallerLines.contains('RestartApplications=no')) {
    stderr.writeln(
      'Windows installer identity, per-user path, and graceful-close/no-restart policy must remain stable.',
    );
    exitCode = 65;
    return;
  }

  final normalizedKey = publicKey.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedKey) ||
      normalizedKey == defaultReleasePublicKeyHex.toLowerCase()) {
    stderr.writeln(
      'QA key must be a 32-byte hex Ed25519 public key distinct from the release key.',
    );
    exitCode = 65;
    return;
  }

  for (final platform in ['android', 'windows']) {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}/updates/qa/$platform/version.json',
    );
    if (uri.scheme != 'https' ||
        uri.host != 'myteam.simogatti.it' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      stderr.writeln(
        'QA updater origin must be the fixed HTTPS MyTeam origin.',
      );
      exitCode = 65;
      return;
    }
  }

  stdout.writeln(
    'QA updater pin and A→B version progression validated for Android and Windows.',
  );
}

bool _isSemver(String value) => RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value);

int _compareVersions(String left, String right) {
  final leftParts = left.split('.').map(int.parse).toList();
  final rightParts = right.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final comparison = leftParts[i].compareTo(rightParts[i]);
    if (comparison != 0) return comparison;
  }
  return 0;
}
