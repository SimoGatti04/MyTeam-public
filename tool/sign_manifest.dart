import 'dart:io';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:myteam/core/services/updater/release_key_pin.dart'
    as release_key_pin;

import 'private_key_file.dart';

/// Single source of truth for the production Ed25519 trust root.
const String kDefaultReleasePublicKeyHex =
    release_key_pin.defaultReleasePublicKeyHex;

void main(List<String> args) {
  if (args.isEmpty || args[0] == '--help' || args[0] == '-h') {
    print('MyTeam Manifest Signing Tool (Ed25519 Detached Signature)');
    print('');
    print('Usage:');
    print('  dart run tool/sign_manifest.dart generate-keys [output_path]');
    print(
      '  dart run tool/sign_manifest.dart sign <path_to_version.json> [--allow-custom-key]',
    );
    print(
      '  dart run tool/sign_manifest.dart verify <path_to_version.json> [public_key_hex] [path_to_sig]',
    );
    print('');
    print('Security Notes:');
    print(
      '  - The private key is NEVER accepted via CLI positional arguments.',
    );
    print(
      '  - Pass private key via MYTEAM_UPDATER_PRIVATE_KEY environment variable or securely via stdin/file.',
    );
    print(
      '  - In release signing, the tool validates that the private key matches the pinned client public key:',
    );
    print('    $kDefaultReleasePublicKeyHex (fails closed on mismatch).');
    print(
      '  - Use --allow-custom-key ONLY for local/QA testing with synthetic keypairs.',
    );
    exit(0);
  }

  final command = args[0].toLowerCase();

  switch (command) {
    case 'generate-keys':
      final keyPair = ed.generateKey();
      final pubHex = hex.encode(keyPair.publicKey.bytes);
      final privHex = hex.encode(keyPair.privateKey.bytes);

      final outputPath = args.length > 1 ? args[1] : '.ed25519_private.key';
      final keyFile = File(outputPath);
      final installedPath = writePrivateKeyFileSafely(
        keyFile.path,
        privHex.trim(),
      );

      print('=== Ed25519 Key Pair Generated ===');
      print('Public Key Hex (embed in client): $pubHex');
      print(
        'Private Key Hex saved to $installedPath with restricted 0600 permissions (keep secret, never commit!).',
      );
      break;

    case 'sign':
      if (args.length < 2) {
        print('Error: Missing manifest path.');
        exit(1);
      }
      final manifestPath = args[1];
      final allowCustomKey = args.contains('--allow-custom-key');

      final manifestFile = File(manifestPath);
      if (!manifestFile.existsSync()) {
        print('Error: Manifest file not found: $manifestPath');
        exit(1);
      }

      // Leggi la chiave privata da env var o da stdin o da file .ed25519_private.key
      String privHex = Platform.environment['MYTEAM_UPDATER_PRIVATE_KEY'] ?? '';
      if (privHex.isEmpty && File('.ed25519_private.key').existsSync()) {
        privHex = File('.ed25519_private.key').readAsStringSync().trim();
      }
      if (privHex.isEmpty) {
        stdout.write('Enter Private Key Hex (hidden/stdin): ');
        privHex = stdin.readLineSync() ?? '';
      }

      if (privHex.trim().isEmpty) {
        print(
          'Error: Private key hex not provided. Set MYTEAM_UPDATER_PRIVATE_KEY or pipe to stdin.',
        );
        exit(1);
      }

      final privBytes = hex.decode(privHex.trim());
      if (privBytes.length != 64) {
        print(
          'Error: Invalid Ed25519 private key length. Expected 64 bytes (128 hex chars), got ${privBytes.length} bytes.',
        );
        exit(1);
      }

      final privateKey = ed.PrivateKey(privBytes);
      final derivedPublicKey = ed.public(privateKey);
      final derivedPubHex = hex.encode(derivedPublicKey.bytes).toLowerCase();

      // P1: VALIDAZIONE PROVENANCE FAIL-CLOSED
      // Verifica che la chiave privata derivi esattamente la chiave pubblica di release incorporata nel client
      if (derivedPubHex != kDefaultReleasePublicKeyHex.toLowerCase()) {
        if (!allowCustomKey) {
          print('SECURITY ERROR (FAIL-CLOSED): Signing key mismatch!');
          print('The provided private key derives public key:');
          print('  $derivedPubHex');
          print('which DOES NOT match the pinned client release public key:');
          print('  $kDefaultReleasePublicKeyHex');
          print('');
          print(
            'Refusing to sign release manifest. If you are running local QA/test with synthetic keys,',
          );
          print('pass --allow-custom-key explicitly.');
          exit(3);
        } else {
          print(
            'WARNING: Signing with custom synthetic public key: $derivedPubHex (--allow-custom-key enabled)',
          );
        }
      } else {
        print(
          'PROVENANCE VERIFIED: Signing key matches pinned client release public key.',
        );
      }

      final manifestBytes = manifestFile.readAsBytesSync();
      final signature = ed.sign(privateKey, manifestBytes);
      final sigHex = hex.encode(signature);

      final sigFile = File('$manifestPath.sig');
      sigFile.writeAsStringSync('${sigHex.trim()}\n', flush: true);

      print('Success: Signed $manifestPath');
      print('Detached signature written to ${sigFile.path}');
      break;

    case 'verify':
      if (args.length < 2) {
        print(
          'Error: Usage: verify <manifest_path> [public_key_hex] [sig_path]',
        );
        exit(1);
      }
      final manifestPath = args[1];
      final manifestFile = File(manifestPath);
      if (!manifestFile.existsSync()) {
        print('Error: Manifest file not found: $manifestPath');
        exit(1);
      }

      // Default alla chiave pubblica di release se non specificata
      final pubHex = (args.length > 2 && !args[2].startsWith('-'))
          ? args[2].trim()
          : kDefaultReleasePublicKeyHex;
      final sigPath = args.length > 3 ? args[3] : '$manifestPath.sig';
      final sigFile = File(sigPath);
      if (!sigFile.existsSync()) {
        print('Error: Signature file not found: $sigPath');
        exit(1);
      }

      final manifestBytes = manifestFile.readAsBytesSync();
      final sigHex = sigFile.readAsStringSync().trim();
      final pubBytes = hex.decode(pubHex);
      final sigBytes = hex.decode(sigHex);

      final publicKey = ed.PublicKey(pubBytes);
      final isValid = ed.verify(
        publicKey,
        manifestBytes,
        Uint8List.fromList(sigBytes),
      );

      if (isValid) {
        print(
          'VERIFICATION SUCCESS: Signature is valid for $manifestPath (public key: $pubHex)',
        );
      } else {
        print(
          'VERIFICATION FAILED: Signature is invalid or manifest was tampered!',
        );
        exit(2);
      }
      break;

    default:
      print('Unknown command: $command');
      exit(1);
  }
}
