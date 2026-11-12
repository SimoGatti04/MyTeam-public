import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../debug_logger.dart';
import 'manifest_signature_verifier.dart';
import 'release_key_pin.dart' as release_key_pin;

/// Servizio per la verifica crittografica dell'integrità e dell'autenticità.
///
/// Sicurezza:
/// - Verifica asimmetrica Ed25519 con chiave pubblica incorporata nel client.
/// - Nessuna chiave privata è inclusa nel codice o negli artefatti pubblici.
/// - Nessun bypass della firma consentito nelle build di release.
/// - Calcolo dello SHA-256 degli artefatti in modalità streaming per evitare consumi di memoria.
class CryptoVerifier {
  /// Chiave pubblica Ed25519 per la verifica del manifest di release.
  /// La chiave privata associata non è inclusa nel client o nel repository;
  /// la firma richiede un signer esterno autorizzato.
  static const String defaultReleasePublicKeyHex =
      release_key_pin.defaultReleasePublicKeyHex;

  /// Calcola lo SHA-256 di un file locale in streaming per efficienza di memoria
  static Future<String> computeFileSha256(File file) async {
    if (!await file.exists()) {
      throw FileSystemException(
        'File non trovato per verifica checksum',
        file.path,
      );
    }
    final stream = file.openRead();
    final digest = await sha256.bind(stream).first;
    return digest.toString().toLowerCase();
  }

  /// Verifica se il file corrisponde allo SHA-256 atteso
  static Future<bool> verifySha256(File file, String expectedSha256) async {
    final actualHash = await computeFileSha256(file);
    return actualHash == expectedSha256.trim().toLowerCase();
  }

  /// Verifica la firma digitale asimmetrica Ed25519 dei byte grezzi del manifest.
  /// Formato: detached signature esadecimale (64 byte = 128 caratteri hex).
  static bool verifyManifestEd25519({
    required List<int> manifestBytes,
    required String signatureHex,
    String? publicKeyHex,
  }) {
    final trimmedSig = signatureHex.trim();
    if (trimmedSig.isEmpty || manifestBytes.isEmpty) {
      DebugLogger.warning('CryptoVerifier: Manifest o firma vuoti.');
      return false;
    }
    final effectivePubHex =
        (publicKeyHex != null && publicKeyHex.trim().isNotEmpty)
        ? publicKeyHex.trim()
        : defaultReleasePublicKeyHex;
    final valid = verifyManifestSignature(
      manifestBytes: manifestBytes,
      signatureHex: trimmedSig,
      publicKeyHex: effectivePubHex,
    );
    if (!valid) {
      DebugLogger.error('CryptoVerifier: verifica Ed25519 non valida.');
    }
    return valid;
  }

  /// Verifica se un URI rispetta i vincoli di sicurezza:
  /// - Obbligo assoluto di HTTPS
  /// - Host locale consentito SOLO se corrisponde esattamente a localhost, 127.0.0.1 o ::1 E non siamo in kReleaseMode.
  /// Previene vulnerabilità di hostname che contengono la sottostringa 'localhost' (es. evil-localhost.com).
  /// Predicato di autorizzazione endpoint per test e QA (se null, usa la policy predefinita).
  @visibleForTesting
  static bool Function(Uri uri)? allowedEndpointOverrideForTesting;

  /// Verifica se un URI rispetta i vincoli di sicurezza:
  /// - Obbligo assoluto di HTTPS
  /// - Host di produzione consentito: ESCLUSIVAMENTE 'myteam.simogatti.it' (nessun wildcard generico *.simogatti.it)
  /// - Host locale consentito SOLO se corrisponde esattamente a localhost, 127.0.0.1 o ::1 E non siamo in kReleaseMode.
  /// - Porta standard (443 per HTTPS, o qualsiasi solo in non-release su localhost)
  /// - Nessuna credenziale embedded nell'URI (user:pass@)
  static bool isAllowedEndpointUrl(Uri uri) {
    // Test policy is unavailable in release builds, even if accidentally left assigned.
    if (!kReleaseMode && allowedEndpointOverrideForTesting != null) {
      return allowedEndpointOverrideForTesting!(uri);
    }

    // Rifiuta URI con credenziali incorporate per prevenire attacchi di offuscamento
    if (uri.userInfo.isNotEmpty) {
      return false;
    }

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    if (scheme == 'https') {
      // Host di produzione rigido: esattamente myteam.simogatti.it (porta standard 443 o non specificata)
      if (host == 'myteam.simogatti.it') {
        return !uri.hasPort || uri.port == 443;
      }
      if (!kReleaseMode &&
          (host == 'localhost' || host == '127.0.0.1' || host == '::1')) {
        return true;
      }
      return false;
    }

    // In modalità release NESSUNA connessione HTTP non cifrata è consentita
    if (kReleaseMode) {
      return false;
    }

    if (scheme == 'http') {
      if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
        return true;
      }
    }

    return false;
  }

  /// Verifica che l'URL dell'artefatto provenga da un'origine autorizzata
  static bool isAllowedArtifactUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return isAllowedEndpointUrl(uri);
  }
}
