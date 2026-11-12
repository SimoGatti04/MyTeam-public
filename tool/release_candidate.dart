import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:myteam/core/services/updater/manifest_signature_verifier.dart';
import 'package:myteam/core/services/updater/release_key_pin.dart';

const _androidApplicationId = 'it.simogatti.myteam';
const _flutterVersion = '3.38.1';
const _jdkMajor = 17;
const _innoSetupVersion = '6.7.1';
const _productionArtifactRoot = 'https://myteam.simogatti.it/updates/releases/';
const _manifestKeys = {
  'channel',
  'version_name',
  'version_code',
  'release_date',
  'changelog',
  'mandatory',
  'min_supported_version_code',
  'platforms',
};
final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final _versionPattern = RegExp(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$');
final _commitPattern = RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$');

/// Build-once release bundle creation and deterministic local verification.
/// Signing is intentionally delegated to tool/sign_manifest.dart so the private
/// Ed25519 key never appears in this program's arguments or generated metadata.
Future<void> main(List<String> args) async {
  try {
    if (args.isEmpty || args.first == '--help' || args.first == '-h') {
      _usage();
      return;
    }
    switch (args.first) {
      case 'prepare':
        await _prepare(_parseOptions(args.skip(1)));
        return;
      case 'verify-archive':
        if (args.length != 3) {
          throw const FormatException(
            'Expected archive and SHA256 sidecar paths.',
          );
        }
        await verifyArchiveSha256(File(args[1]), File(args[2]));
        stdout.writeln('Release archive SHA-256 PASS.');
        return;
      case 'validate':
        if (args.length != 2) {
          throw const FormatException('Expected candidate directory.');
        }
        await validateCandidate(Directory(args[1]));
        stdout.writeln('Release candidate validation PASS.');
        return;
      default:
        throw const FormatException(
          'Expected prepare, validate, or verify-archive command.',
        );
    }
  } on FormatException catch (error) {
    stderr.writeln('Release candidate validation failed: ${error.message}');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Release candidate file error: ${error.message}');
    exitCode = 1;
  }
}

void _usage() {
  stdout.writeln(
    '''MyTeam production candidate tools

Prepare after both signed installers are built:
  dart run tool/release_candidate.dart prepare \\
    --out DIR --version-name X.Y.Z --version-code N \\
    --android-apk FILE --windows-installer FILE --commit SHA \\
    --workflow-run-id ID --android-cert-sha256 HEX \\
    --windows-authenticode-sha256 HEX --changelog TEXT

Then sign the exact version.json bytes using the externally held pinned key:
  dart run tool/sign_manifest.dart sign DIR/version.json
  sha256sum DIR/*.apk DIR/*.exe DIR/version.json DIR/version.json.sig \\
    DIR/build-provenance.json > DIR/SHA256SUMS
  dart run tool/release_candidate.dart validate DIR
  dart run tool/release_candidate.dart verify-archive DIR.tar.gz DIR.tar.gz.sha256

Validation is read-only and always uses the public key pinned in the production client.''',
  );
}

Map<String, String> _parseOptions(Iterable<String> args) {
  final values = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--') || !arg.contains('=')) {
      throw FormatException('Options must use --name=value syntax: $arg');
    }
    final split = arg.indexOf('=');
    final key = arg.substring(2, split);
    if (values.containsKey(key)) {
      throw FormatException('Duplicate option: --$key');
    }
    values[key] = arg.substring(split + 1);
  }
  return values;
}

String _required(Map<String, String> values, String key) {
  final value = values[key]?.trim();
  if (value == null || value.isEmpty) throw FormatException('Missing --$key.');
  return value;
}

Future<void> _prepare(Map<String, String> values) async {
  const expected = {
    'out',
    'version-name',
    'version-code',
    'android-apk',
    'windows-installer',
    'commit',
    'workflow-run-id',
    'android-cert-sha256',
    'windows-authenticode-sha256',
    'previous-version-code',
    'changelog',
  };
  final unknown = values.keys.where((key) => !expected.contains(key));
  if (unknown.isNotEmpty) {
    throw FormatException('Unknown option: --${unknown.first}');
  }
  final version = _required(values, 'version-name');
  final code = int.tryParse(_required(values, 'version-code'));
  final commit = _required(values, 'commit').toLowerCase();
  final runId = _required(values, 'workflow-run-id');
  final previousCode = int.tryParse(_required(values, 'previous-version-code'));
  final androidFingerprint = _fingerprint(
    _required(values, 'android-cert-sha256'),
    'Android certificate',
  );
  final windowsFingerprint = _fingerprint(
    _required(values, 'windows-authenticode-sha256'),
    'Windows Authenticode certificate',
  );
  if (!_versionPattern.hasMatch(version)) {
    throw const FormatException('Version must be numeric X.Y.Z.');
  }
  if (code == null || code < 1 || code > 2147483647) {
    throw const FormatException(
      'Version code must be a positive Android integer.',
    );
  }
  if (previousCode == null || previousCode < 0 || code <= previousCode) {
    throw const FormatException(
      'Version code must exceed the explicitly supplied previous production version code.',
    );
  }
  if (!_commitPattern.hasMatch(commit)) {
    throw const FormatException('Commit must be a full Git SHA.');
  }
  if (!RegExp(r'^\d+$').hasMatch(runId)) {
    throw const FormatException('Workflow run ID must be numeric.');
  }
  final androidSource = File(_required(values, 'android-apk'));
  final windowsSource = File(_required(values, 'windows-installer'));
  if (!await FileSystemEntity.isFile(androidSource.path) ||
      !await FileSystemEntity.isFile(windowsSource.path)) {
    throw const FormatException('Both built release artifacts must exist.');
  }
  final out = Directory(_required(values, 'out'));
  if (await out.exists() && !(await out.list().isEmpty)) {
    throw const FormatException(
      'Output directory must be absent or empty; refusing to overwrite candidate material.',
    );
  }
  await out.create(recursive: true);

  final androidName = 'MyTeam-$version+$code.apk';
  final windowsName = 'MyTeam-Setup-$version-$code.exe';
  final androidFile = await androidSource.copy('${out.path}/$androidName');
  final windowsFile = await windowsSource.copy('${out.path}/$windowsName');
  final androidSha = await _sha256(androidFile);
  final windowsSha = await _sha256(windowsFile);
  final now = DateTime.now().toUtc();
  final manifest = <String, Object>{
    'version_name': version,
    'version_code': code,
    'release_date': now.toIso8601String(),
    'changelog': _required(values, 'changelog'),
    'mandatory': false,
    'min_supported_version_code': 1,
    'channel': 'production',
    'platforms': {
      'android': {
        'url': '$_productionArtifactRoot$version/$androidName',
        'sha256': androidSha,
        'size_bytes': await androidFile.length(),
      },
      'windows': {
        'url': '$_productionArtifactRoot$version/$windowsName',
        'sha256': windowsSha,
        'size_bytes': await windowsFile.length(),
      },
    },
  };
  final provenance = <String, Object>{
    'schema_version': 1,
    'channel': 'production',
    'version_name': version,
    'version_code': code,
    'previous_production_version_code': previousCode,
    'git_commit': commit,
    'workflow_run_id': runId,
    'flutter_version': _flutterVersion,
    'jdk_major': _jdkMajor,
    'inno_setup_version': _innoSetupVersion,
    'android_application_id': _androidApplicationId,
    'android_certificate_sha256': androidFingerprint,
    'android_certificate_verified': true,
    'windows_authenticode_sha256': windowsFingerprint,
    'windows_authenticode_verified': true,
    'built_at_utc': now.toIso8601String(),
    'artifacts': {
      androidName: {
        'sha256': androidSha,
        'size_bytes': await androidFile.length(),
      },
      windowsName: {
        'sha256': windowsSha,
        'size_bytes': await windowsFile.length(),
      },
    },
  };
  await File('${out.path}/version.json').writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    flush: true,
  );
  await File('${out.path}/build-provenance.json').writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(provenance)}\n',
    flush: true,
  );
  stdout.writeln(
    'Prepared unsigned candidate inputs in ${out.path}; manifest signing and checksum generation remain required.',
  );
}

String _fingerprint(String value, String label) {
  final normalized = value.replaceAll(':', '').toLowerCase();
  if (!_sha256Pattern.hasMatch(normalized)) {
    throw FormatException(
      '$label fingerprint must be 64 hexadecimal characters.',
    );
  }
  return normalized;
}

/// Validates the exact candidate directory without mutation. publicKeyHex is a
/// test seam; the CLI never accepts an alternate production trust root.
Future<void> validateCandidate(
  Directory directory, {
  String? publicKeyHex,
}) async {
  if (!await directory.exists()) {
    throw const FormatException('Candidate directory does not exist.');
  }
  final manifestFile = File('${directory.path}/version.json');
  final signatureFile = File('${directory.path}/version.json.sig');
  final provenanceFile = File('${directory.path}/build-provenance.json');
  final sumsFile = File('${directory.path}/SHA256SUMS');
  for (final file in [manifestFile, signatureFile, provenanceFile, sumsFile]) {
    if (!await FileSystemEntity.isFile(file.path)) {
      throw FormatException('Missing ${file.uri.pathSegments.last}.');
    }
  }
  final manifestBytes = await manifestFile.readAsBytes();
  final signature = (await signatureFile.readAsString()).trim();
  if (!RegExp(r'^[0-9a-fA-F]{128}$').hasMatch(signature) ||
      !_verifyManifestEd25519(
        manifestBytes: manifestBytes,
        signatureHex: signature,
        publicKeyHex: publicKeyHex ?? defaultReleasePublicKeyHex,
      )) {
    throw const FormatException(
      'Detached Ed25519 signature is invalid for the pinned production key.',
    );
  }
  final decoded = jsonDecode(utf8.decode(manifestBytes));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('version.json must be a JSON object.');
  }
  if (decoded.keys.toSet().difference(_manifestKeys).isNotEmpty ||
      !_manifestKeys.containsAll(decoded.keys) ||
      decoded.keys.length != _manifestKeys.length) {
    throw const FormatException(
      'Manifest root keys do not match the release contract.',
    );
  }
  final version = decoded['version_name'];
  final code = decoded['version_code'];
  if (decoded['channel'] != 'production' ||
      version is! String ||
      !_versionPattern.hasMatch(version) ||
      code is! int ||
      code < 1 ||
      code > 2147483647 ||
      (decoded['release_date'] is! String ||
          (decoded['release_date'] as String).trim().isEmpty) ||
      decoded['changelog'] is! String ||
      (decoded['changelog'] as String).trim().isEmpty ||
      decoded['mandatory'] is! bool ||
      decoded['min_supported_version_code'] is! int ||
      (decoded['min_supported_version_code'] as int) < 1) {
    throw const FormatException(
      'Manifest production channel or version identity is invalid.',
    );
  }
  final platforms = decoded['platforms'];
  if (platforms is! Map<String, dynamic> ||
      platforms.keys.toSet().difference({'android', 'windows'}).isNotEmpty ||
      !platforms.keys.toSet().containsAll({'android', 'windows'}) ||
      platforms.length != 2) {
    throw const FormatException(
      'Manifest must contain exactly Android and Windows artifacts.',
    );
  }
  final artifacts = <String, File>{};
  for (final platform in ['android', 'windows']) {
    final value = platforms[platform];
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference({
          'url',
          'sha256',
          'size_bytes',
        }).isNotEmpty ||
        value.length != 3) {
      throw FormatException('$platform manifest entry must be an object.');
    }
    final uri = Uri.tryParse(value['url'] as String? ?? '');
    final expectedName = platform == 'android'
        ? 'MyTeam-$version+$code.apk'
        : 'MyTeam-Setup-$version-$code.exe';
    final expectedUrl = '$_productionArtifactRoot$version/$expectedName';
    if (uri == null ||
        !_isAllowedArtifactUrl(uri) ||
        value['url'] != expectedUrl ||
        uri.toString() != expectedUrl) {
      throw FormatException(
        '$platform URL must be the exact immutable production URL for this version and filename.',
      );
    }
    final artifact = File('${directory.path}/$expectedName');
    if (!await FileSystemEntity.isFile(artifact.path)) {
      throw FormatException('Missing $expectedName.');
    }
    final expectedSha = value['sha256'];
    final expectedSize = value['size_bytes'];
    if (expectedSha is! String ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedSha) ||
        expectedSize is! int ||
        expectedSize <= 0) {
      throw FormatException(
        '$platform artifact hash or size metadata is invalid.',
      );
    }
    if (await artifact.length() != expectedSize ||
        await _sha256(artifact) != expectedSha.toLowerCase()) {
      throw FormatException(
        '$platform artifact size or SHA-256 does not match version.json.',
      );
    }
    artifacts[expectedName] = artifact;
  }

  final provenance = jsonDecode(await provenanceFile.readAsString());
  if (provenance is! Map<String, dynamic> ||
      provenance['schema_version'] != 1 ||
      provenance['channel'] != 'production' ||
      provenance['version_name'] != version ||
      provenance['version_code'] != code ||
      provenance['previous_production_version_code'] is! int ||
      (provenance['previous_production_version_code'] as int) < 0 ||
      code <= (provenance['previous_production_version_code'] as int) ||
      provenance['android_application_id'] != _androidApplicationId ||
      provenance['flutter_version'] != _flutterVersion ||
      provenance['jdk_major'] != _jdkMajor ||
      provenance['inno_setup_version'] != _innoSetupVersion ||
      provenance['android_certificate_verified'] != true ||
      provenance['windows_authenticode_verified'] != true ||
      !_commitPattern.hasMatch(provenance['git_commit'] as String? ?? '') ||
      !RegExp(
        r'^\d+$',
      ).hasMatch(provenance['workflow_run_id'] as String? ?? '') ||
      !_sha256Pattern.hasMatch(
        provenance['android_certificate_sha256'] as String? ?? '',
      ) ||
      !_sha256Pattern.hasMatch(
        provenance['windows_authenticode_sha256'] as String? ?? '',
      )) {
    throw const FormatException(
      'Build provenance is incomplete, mismatched, or does not certify both platform signers.',
    );
  }
  final provenanceArtifacts = provenance['artifacts'];
  for (final entry in artifacts.entries) {
    final record = provenanceArtifacts is Map<String, dynamic>
        ? provenanceArtifacts[entry.key]
        : null;
    if (record is! Map<String, dynamic> ||
        record['sha256'] != await _sha256(entry.value) ||
        record['size_bytes'] != await entry.value.length()) {
      throw FormatException('Build provenance does not match ${entry.key}.');
    }
  }

  final expectedFiles = <String>{
    'version.json',
    'version.json.sig',
    'build-provenance.json',
    ...artifacts.keys,
  };
  final checksums = <String, String>{};
  for (final line in (await sumsFile.readAsLines()).where(
    (line) => line.trim().isNotEmpty,
  )) {
    final match = RegExp(
      r'^([0-9a-f]{64})  ([A-Za-z0-9._+-]+)$',
    ).firstMatch(line);
    if (match == null || checksums.containsKey(match.group(2))) {
      throw const FormatException(
        'SHA256SUMS has invalid or duplicate entries.',
      );
    }
    checksums[match.group(2)!] = match.group(1)!;
  }
  if (checksums.keys.toSet().difference(expectedFiles).isNotEmpty ||
      !checksums.keys.toSet().containsAll(expectedFiles)) {
    throw const FormatException(
      'SHA256SUMS must cover exactly the candidate payload files.',
    );
  }
  for (final name in expectedFiles) {
    final file = File('${directory.path}/$name');
    if (checksums[name] != await _sha256(file)) {
      throw FormatException('SHA256SUMS mismatch for $name.');
    }
  }
}

Future<void> verifyArchiveSha256(File archive, File sidecar) async {
  if (!await FileSystemEntity.isFile(archive.path) ||
      !await FileSystemEntity.isFile(sidecar.path)) {
    throw const FormatException(
      'Release archive or SHA256 sidecar is missing.',
    );
  }
  final lines = (await sidecar.readAsLines())
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.length != 1) {
    throw const FormatException(
      'Archive sidecar must contain exactly one checksum row.',
    );
  }
  final match = RegExp(
    r'^([0-9a-f]{64})  ([A-Za-z0-9._+-]+)$',
  ).firstMatch(lines.single);
  if (match == null ||
      match.group(2) != archive.uri.pathSegments.last ||
      match.group(1) != await _sha256(archive)) {
    throw const FormatException('Release archive SHA-256 sidecar mismatch.');
  }
}

Future<String> _sha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString().toLowerCase();

bool _verifyManifestEd25519({
  required List<int> manifestBytes,
  required String signatureHex,
  required String publicKeyHex,
}) {
  return verifyManifestSignature(
    manifestBytes: manifestBytes,
    signatureHex: signatureHex,
    publicKeyHex: publicKeyHex,
  );
}

bool _isAllowedArtifactUrl(Uri uri) =>
    uri.scheme.toLowerCase() == 'https' &&
    uri.host.toLowerCase() == 'myteam.simogatti.it' &&
    (!uri.hasPort || uri.port == 443) &&
    uri.userInfo.isEmpty &&
    !uri.hasQuery &&
    !uri.hasFragment;
