import 'dart:io';

/// Writes private key bytes only after a same-directory, owner-only temporary
/// file has been created and its permissions verified.
///
/// Windows is intentionally unsupported until the tool can create and verify a
/// restrictive Windows DACL. No private bytes are written there.
String writePrivateKeyFileSafely(String outputPath, String privateKeyHex) {
  if (!Platform.isMacOS && !Platform.isLinux) {
    throw UnsupportedError(
      'Private-key file generation is supported only on macOS/Linux; '
      'Windows ACL handling is not implemented.',
    );
  }

  final requested = File(outputPath).absolute;
  final requestedName = requested.uri.pathSegments.isEmpty
      ? ''
      : requested.uri.pathSegments.last;
  if (requestedName.isEmpty || requestedName == '.' || requestedName == '..') {
    throw FileSystemException('Invalid private-key output path.');
  }
  final parent = Directory(requested.parent.path).resolveSymbolicLinksSync();
  final destination = '$parent/$requestedName';
  if (FileSystemEntity.typeSync(destination, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw FileSystemException('Refusing to replace an existing key file.');
  }

  final commands = Platform.isMacOS
      ? const {
          'mktemp': '/usr/bin/mktemp',
          'chmod': '/bin/chmod',
          'stat': '/usr/bin/stat',
          'ln': '/bin/ln',
        }
      : const {
          'mktemp': '/usr/bin/mktemp',
          'chmod': '/bin/chmod',
          'stat': '/usr/bin/stat',
          'ln': '/bin/ln',
        };
  for (final path in commands.values) {
    if (!File(path).existsSync()) {
      throw FileSystemException('Required secure file utility is unavailable.');
    }
  }

  // Refuse shared-writable parents, where another account could replace paths.
  final directoryMode = _readMode(commands['stat']!, parent);
  if ((directoryMode & 0x12) != 0) {
    throw FileSystemException(
      'Refusing to write a private key in a group/world-writable directory.',
    );
  }

  // mktemp -d creates the private staging directory atomically with restrictive
  // permissions even under umask 000. The key file is created inside it with
  // mktemp as well, so no key bytes are written before its 0600 mode is proven.
  final directoryResult = Process.runSync(commands['mktemp']!, [
    '-d',
    '$parent/.myteam-private-key.XXXXXXXXXX',
  ]);
  if (directoryResult.exitCode != 0) {
    throw FileSystemException('Could not securely create a staging directory.');
  }
  final stagingDirectory = directoryResult.stdout.toString().trim();
  var installed = false;
  String? temporary;
  var installedIdentity = '';
  try {
    if (stagingDirectory.isEmpty ||
        Directory(stagingDirectory).absolute.parent.path != parent ||
        FileSystemEntity.typeSync(stagingDirectory, followLinks: false) !=
            FileSystemEntityType.directory ||
        _readMode(commands['stat']!, stagingDirectory) != 0x1c0) {
      throw FileSystemException(
        'Staging directory is not an owner-only directory (0700).',
      );
    }

    final fileResult = Process.runSync(commands['mktemp']!, [
      '$stagingDirectory/key.XXXXXXXXXX',
    ]);
    if (fileResult.exitCode != 0) {
      throw FileSystemException('Could not securely create a key file.');
    }
    temporary = fileResult.stdout.toString().trim();
    if (temporary.isEmpty ||
        Directory(temporary).absolute.parent.path != stagingDirectory ||
        FileSystemEntity.typeSync(temporary, followLinks: false) !=
            FileSystemEntityType.file ||
        _readMode(commands['stat']!, temporary) != 0x180) {
      throw FileSystemException(
        'Temporary key file is not owner-only (0600) before writing.',
      );
    }

    final file = File(temporary).openSync(mode: FileMode.writeOnly);
    try {
      file.writeStringSync('$privateKeyHex\n');
      file.flushSync();
    } finally {
      file.closeSync();
    }
    if (_readMode(commands['stat']!, temporary) != 0x180) {
      throw FileSystemException(
        'Temporary key file mode changed during write.',
      );
    }
    installedIdentity = _readIdentity(commands['stat']!, temporary);

    // Atomic hard-link creation is no-clobber: the fully written inode becomes
    // visible at the requested path in one operation. Both paths share a parent
    // filesystem. Then remove only our staging name.
    final link = Process.runSync(commands['ln']!, [temporary, destination]);
    if (link.exitCode != 0) {
      throw FileSystemException(
        'Could not atomically install the key without replacing a target.',
      );
    }
    if (_readIdentity(commands['stat']!, destination) != installedIdentity ||
        _readMode(commands['stat']!, destination) != 0x180) {
      throw FileSystemException('Installed private key failed verification.');
    }
    File(temporary).deleteSync();
    temporary = null;
    installed = true;
    return destination;
  } finally {
    if (temporary != null &&
        FileSystemEntity.typeSync(temporary, followLinks: false) ==
            FileSystemEntityType.file) {
      File(temporary).deleteSync();
    }
    if (!installed &&
        installedIdentity.isNotEmpty &&
        FileSystemEntity.typeSync(destination, followLinks: false) ==
            FileSystemEntityType.file &&
        _readIdentity(commands['stat']!, destination) == installedIdentity) {
      File(destination).deleteSync();
    }
    if (stagingDirectory.isNotEmpty &&
        FileSystemEntity.typeSync(stagingDirectory, followLinks: false) ==
            FileSystemEntityType.directory) {
      Directory(stagingDirectory).deleteSync(recursive: true);
    }
  }
}

int _readMode(String statPath, String path) {
  final args = Platform.isMacOS ? ['-f', '%Lp', path] : ['-c', '%a', path];
  final result = Process.runSync(statPath, args);
  if (result.exitCode != 0) {
    throw FileSystemException('Could not verify filesystem permissions.');
  }
  final mode = int.tryParse(result.stdout.toString().trim(), radix: 8);
  if (mode == null) {
    throw FileSystemException('Could not parse filesystem permissions.');
  }
  return mode;
}

String _readIdentity(String statPath, String path) {
  final args = Platform.isMacOS ? ['-f', '%d:%i', path] : ['-c', '%d:%i', path];
  final result = Process.runSync(statPath, args);
  if (result.exitCode != 0) {
    throw FileSystemException('Could not verify key file identity.');
  }
  return result.stdout.toString().trim();
}
