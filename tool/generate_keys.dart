import 'dart:io';
import 'package:convert/convert.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'private_key_file.dart';

void main(List<String> args) {
  final keyPair = ed.generateKey();
  final pubHex = hex.encode(keyPair.publicKey.bytes);
  final privHex = hex.encode(keyPair.privateKey.bytes);

  print('=== Ed25519 Key Pair Generator ===');
  print('Public Key Hex (embed in client): $pubHex');

  // Determina il percorso di output (default: .ed25519_private.key)
  final outputPath = args.isNotEmpty ? args[0] : '.ed25519_private.key';
  final keyFile = File(outputPath);

  final installedPath = writePrivateKeyFileSafely(keyFile.path, privHex.trim());

  print(
    'Private Key Hex written to $installedPath with restricted permissions (0600).',
  );
  print(
    'SECURITY REMINDER: Keep secret, never commit to git, never log or share!',
  );
}
