import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

/// Pure-Dart Ed25519 verification shared by the Flutter client and release CLI.
/// The caller supplies its trust root; the production CLI always passes the
/// repository-pinned key and does not expose a key override on its command line.
bool verifyManifestSignature({
  required List<int> manifestBytes,
  required String signatureHex,
  required String publicKeyHex,
}) {
  if (manifestBytes.isEmpty ||
      !RegExp(r'^[0-9a-fA-F]{128}$').hasMatch(signatureHex.trim()) ||
      !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(publicKeyHex.trim())) {
    return false;
  }

  try {
    return ed.verify(
      ed.PublicKey(hex.decode(publicKeyHex.trim())),
      Uint8List.fromList(manifestBytes),
      Uint8List.fromList(hex.decode(signatureHex.trim())),
    );
  } on FormatException {
    return false;
  }
}
