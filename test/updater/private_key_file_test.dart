import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('private key file tools', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('myteam-key-test-');
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    for (final script in [
      'tool/generate_keys.dart',
      'tool/sign_manifest.dart',
    ]) {
      test('$script creates owner-only output under umask 000', () async {
        final output = '${directory.path}/synthetic.key';
        final result = await Process.run('/bin/sh', [
          '-c',
          'umask 000; exec "\$@"',
          'myteam-test',
          'dart',
          'run',
          script,
          if (script.endsWith('sign_manifest.dart')) 'generate-keys',
          output,
        ], workingDirectory: Directory.current.path);

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final keyFile = File(output);
        expect(await keyFile.exists(), isTrue);
        expect(await _mode(output), 0x180, reason: 'expected mode 0600');
        final keyText = await keyFile.readAsString();
        expect(keyText.trim(), matches(RegExp(r'^[0-9a-fA-F]{64,}$')));
        expect(
          '${result.stdout}${result.stderr}',
          isNot(contains(keyText.trim())),
        );
        expect(
          directory.listSync().where(
            (entry) => entry.basename.startsWith('.myteam-private-key.'),
          ),
          isEmpty,
          reason: 'temporary staging directory should be removed',
        );
      }, skip: Platform.isWindows ? 'POSIX private-key mode test' : false);
    }

    test('refuses an existing target without changing it', () async {
      final output = File('${directory.path}/existing.key');
      await output.writeAsString('pre-existing marker');
      final result = await Process.run('/bin/sh', [
        '-c',
        'umask 000; exec "\$@"',
        'myteam-test',
        'dart',
        'run',
        'tool/generate_keys.dart',
        output.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, isNot(0));
      expect(await output.readAsString(), 'pre-existing marker');
      expect(
        '${result.stdout}${result.stderr}',
        isNot(contains('pre-existing marker')),
      );
      expect(
        directory.listSync().where(
          (entry) => entry.basename.startsWith('.myteam-private-key.'),
        ),
        isEmpty,
      );
    }, skip: Platform.isWindows ? 'POSIX private-key mode test' : false);
  });
}

extension on FileSystemEntity {
  String get basename => uri.pathSegments.where((part) => part.isNotEmpty).last;
}

Future<int> _mode(String path) async {
  final stat = Platform.isMacOS
      ? await Process.run('/usr/bin/stat', ['-f', '%Lp', path])
      : await Process.run('/usr/bin/stat', ['-c', '%a', path]);
  expect(stat.exitCode, 0);
  return int.parse(stat.stdout.toString().trim(), radix: 8);
}
