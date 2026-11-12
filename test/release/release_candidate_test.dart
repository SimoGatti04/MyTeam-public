import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:myteam/core/services/updater/crypto_verifier.dart';
import '../../tool/release_candidate.dart';

void main() {
  late Directory temp;
  late ed.KeyPair keyPair;
  late String publicKeyHex;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('myteam-release-candidate-');
    keyPair = ed.generateKey();
    publicKeyHex = hex.encode(keyPair.publicKey.bytes);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'accepts a fully signed, checksummed two-platform candidate idempotently',
    () async {
      final candidate = await _makeCandidate(temp, keyPair);
      await validateCandidate(candidate, publicKeyHex: publicKeyHex);
      await validateCandidate(candidate, publicKeyHex: publicKeyHex);
    },
  );

  test('rejects invalid detached Ed25519 signature', () async {
    final candidate = await _makeCandidate(temp, keyPair);
    await File('${candidate.path}/version.json.sig').writeAsString('00' * 64);
    await expectLater(
      validateCandidate(candidate, publicKeyHex: publicKeyHex),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('signature'),
        ),
      ),
    );
  });

  test(
    'rejects a manifest URL without its immutable version directory',
    () async {
      final candidate = await _makeCandidate(temp, keyPair);
      await _rewriteSignedManifest(candidate, keyPair, (manifest) {
        final platforms = manifest['platforms'] as Map<String, dynamic>;
        final android = platforms['android'] as Map<String, dynamic>;
        android['url'] =
            'https://myteam.simogatti.it/updates/releases/MyTeam-1.0.0+5.apk';
      });
      await expectLater(
        validateCandidate(candidate, publicKeyHex: publicKeyHex),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('exact immutable production URL'),
          ),
        ),
      );
    },
  );

  test('rejects immutable artifact URLs with query or fragment', () async {
    for (final suffix in ['?download=1', '#latest']) {
      final candidate = await _makeCandidate(temp, keyPair);
      await _rewriteSignedManifest(candidate, keyPair, (manifest) {
        final platforms = manifest['platforms'] as Map<String, dynamic>;
        final android = platforms['android'] as Map<String, dynamic>;
        android['url'] =
            'https://myteam.simogatti.it/updates/releases/1.0.0/MyTeam-1.0.0+5.apk$suffix';
      });
      await expectLater(
        validateCandidate(candidate, publicKeyHex: publicKeyHex),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('exact immutable production URL'),
          ),
        ),
      );
    }
  });

  test('rejects non-production manifest channel even when re-signed', () async {
    final candidate = await _makeCandidate(temp, keyPair);
    await _rewriteSignedManifest(candidate, keyPair, (manifest) {
      manifest['channel'] = 'qa';
    });
    await expectLater(
      validateCandidate(candidate, publicKeyHex: publicKeyHex),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('production channel'),
        ),
      ),
    );
  });

  test(
    'rejects artifact bytes that differ from signed manifest hash',
    () async {
      final candidate = await _makeCandidate(temp, keyPair);
      await File(
        '${candidate.path}/MyTeam-1.0.0+5.apk',
      ).writeAsBytes([9, 9, 9]);
      await expectLater(
        validateCandidate(candidate, publicKeyHex: publicKeyHex),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('SHA-256'),
          ),
        ),
      );
    },
  );

  test(
    'rejects a candidate SHA256SUMS row that no longer matches its bundle files',
    () async {
      final candidate = await _makeCandidate(temp, keyPair);
      final sums = File('${candidate.path}/SHA256SUMS');
      final lines = await sums.readAsLines();
      lines[0] = '${'f' * 64}  ${lines[0].split('  ').last}';
      await sums.writeAsString('${lines.join('\n')}\n');
      await expectLater(
        validateCandidate(candidate, publicKeyHex: publicKeyHex),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('SHA256SUMS mismatch'),
          ),
        ),
      );
    },
  );

  test(
    'verifies the external archive checksum sidecar and rejects tampering',
    () async {
      final archive = await File(
        '${temp.path}/candidate.tar.gz',
      ).writeAsBytes([1, 3, 3, 7]);
      final sidecar = File('${temp.path}/candidate.tar.gz.sha256');
      await sidecar.writeAsString(
        '${await CryptoVerifier.computeFileSha256(archive)}  candidate.tar.gz\n',
      );
      await verifyArchiveSha256(archive, sidecar);
      await archive.writeAsBytes([0, 0, 0, 0]);
      await expectLater(
        verifyArchiveSha256(archive, sidecar),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('sidecar mismatch'),
          ),
        ),
      );
    },
  );

  test(
    'rejects a candidate version code that does not advance production',
    () async {
      final candidate = await _makeCandidate(temp, keyPair);
      final file = File('${candidate.path}/build-provenance.json');
      final provenance =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      provenance['previous_production_version_code'] = 5;
      await file.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(provenance)}\n',
      );
      await _rewriteSums(candidate);
      await expectLater(
        validateCandidate(candidate, publicKeyHex: publicKeyHex),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('provenance'),
          ),
        ),
      );
    },
  );

  test('rejects provenance for a different Android package identity', () async {
    final candidate = await _makeCandidate(temp, keyPair);
    final file = File('${candidate.path}/build-provenance.json');
    final provenance =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    provenance['android_application_id'] = 'com.example.myteam_video_app';
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(provenance)}\n',
    );
    await _rewriteSums(candidate);
    await expectLater(
      validateCandidate(candidate, publicKeyHex: publicKeyHex),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('provenance'),
        ),
      ),
    );
  });
}

Future<Directory> _makeCandidate(Directory parent, ed.KeyPair pair) async {
  final dir = Directory(
    '${parent.path}/candidate-${DateTime.now().microsecondsSinceEpoch}',
  );
  await dir.create();
  const version = '1.0.0';
  const code = 5;
  const apkName = 'MyTeam-1.0.0+5.apk';
  const exeName = 'MyTeam-Setup-1.0.0-5.exe';
  final apk = await File('${dir.path}/$apkName').writeAsBytes([1, 2, 3, 4]);
  final exe = await File('${dir.path}/$exeName').writeAsBytes([5, 6, 7, 8]);
  final manifest = <String, Object>{
    'version_name': version,
    'version_code': code,
    'release_date': '2026-11-10T12:00:00.000Z',
    'changelog': 'Initial release candidate',
    'mandatory': false,
    'min_supported_version_code': 1,
    'channel': 'production',
    'platforms': {
      'android': {
        'url': 'https://myteam.simogatti.it/updates/releases/$version/$apkName',
        'sha256': await CryptoVerifier.computeFileSha256(apk),
        'size_bytes': await apk.length(),
      },
      'windows': {
        'url': 'https://myteam.simogatti.it/updates/releases/$version/$exeName',
        'sha256': await CryptoVerifier.computeFileSha256(exe),
        'size_bytes': await exe.length(),
      },
    },
  };
  final manifestBytes = utf8.encode(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
  await File('${dir.path}/version.json').writeAsBytes(manifestBytes);
  await File(
    '${dir.path}/version.json.sig',
  ).writeAsString(hex.encode(ed.sign(pair.privateKey, manifestBytes)));
  final provenance = <String, Object>{
    'schema_version': 1,
    'channel': 'production',
    'version_name': version,
    'version_code': code,
    'previous_production_version_code': 4,
    'git_commit': 'a' * 40,
    'workflow_run_id': '12345',
    'flutter_version': '3.38.1',
    'jdk_major': 17,
    'inno_setup_version': '6.7.1',
    'android_application_id': 'it.simogatti.myteam',
    'android_certificate_sha256': 'b' * 64,
    'android_certificate_verified': true,
    'windows_authenticode_sha256': 'c' * 64,
    'windows_authenticode_verified': true,
    'built_at_utc': '2026-11-10T12:00:00.000Z',
    'artifacts': {
      apkName: {
        'sha256': await CryptoVerifier.computeFileSha256(apk),
        'size_bytes': await apk.length(),
      },
      exeName: {
        'sha256': await CryptoVerifier.computeFileSha256(exe),
        'size_bytes': await exe.length(),
      },
    },
  };
  await File('${dir.path}/build-provenance.json').writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(provenance)}\n',
  );
  await _rewriteSums(dir);
  return dir;
}

Future<void> _rewriteSums(Directory dir) async {
  final files = await dir
      .list()
      .where(
        (entity) =>
            entity is File && entity.uri.pathSegments.last != 'SHA256SUMS',
      )
      .cast<File>()
      .toList();
  files.sort(
    (a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last),
  );
  final rows = <String>[];
  for (final file in files) {
    rows.add(
      '${await CryptoVerifier.computeFileSha256(file)}  ${file.uri.pathSegments.last}',
    );
  }
  await File('${dir.path}/SHA256SUMS').writeAsString('${rows.join('\n')}\n');
}

Future<void> _rewriteSignedManifest(
  Directory dir,
  ed.KeyPair pair,
  void Function(Map<String, dynamic>) mutate,
) async {
  final file = File('${dir.path}/version.json');
  final manifest =
      jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  mutate(manifest);
  final bytes = utf8.encode(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
  await file.writeAsBytes(bytes);
  await File(
    '${dir.path}/version.json.sig',
  ).writeAsString(hex.encode(ed.sign(pair.privateKey, bytes)));
  await _rewriteSums(dir);
}
