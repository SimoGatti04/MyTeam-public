import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'debug_logger.dart';

/// Servizio per verificare e installare FFmpeg automaticamente
class FFmpegInstallationService {
  /// Verifica se FFmpeg è installato e accessibile
  /// Su Windows, aggiorna il PATH prima di verificare
  static Future<bool> isFFmpegInstalled() async {
    try {
      // Su Windows, aggiorna il PATH per includere percorsi comuni di FFmpeg
      if (Platform.isWindows) {
        // Aggiorna PATH con percorsi comuni di FFmpeg
        final pathEnv = Platform.environment['PATH'] ?? '';
        final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
        
        // Percorsi comuni di FFmpeg
        final commonPaths = [
          r'C:\Program Files\ffmpeg\bin',
          r'C:\ffmpeg\bin',
          r'C:\Program Files (x86)\ffmpeg\bin',
        ];
        
        // Percorso winget (se installato tramite winget)
        if (userProfile.isNotEmpty) {
          final wingetPackagesPath = '$userProfile\\AppData\\Local\\Microsoft\\WinGet\\Packages';
          final wingetPackagesDir = Directory(wingetPackagesPath);
          if (await wingetPackagesDir.exists()) {
            // Cerca cartella Gyan.FFmpeg_*
            try {
              final packages = await wingetPackagesDir.list().toList();
              for (final package in packages) {
                if (package is Directory) {
                  final packageName = package.path.split(Platform.pathSeparator).last;
                  if (packageName.startsWith('Gyan.FFmpeg_')) {
                    // Cerca ffmpeg.exe nella struttura (ffmpeg-*-full_build\bin\ffmpeg.exe)
                    final binDir = Directory('${package.path}\\ffmpeg-8.0-full_build\\bin');
                    if (await binDir.exists()) {
                      final ffmpegExe = File('${binDir.path}\\ffmpeg.exe');
                      if (await ffmpegExe.exists()) {
                        commonPaths.add(binDir.path);
                        DebugLogger.info('✅ [FFmpegInstallation] Trovato FFmpeg in winget: ${binDir.path}');
                      }
                    } else {
                      // Prova a cercare ricorsivamente
                      try {
                        final ffmpegFiles = await package.list(recursive: true, followLinks: false).toList();
                        for (final file in ffmpegFiles) {
                          if (file is File && file.path.endsWith('ffmpeg.exe')) {
                            final binPath = file.parent.path;
                            commonPaths.add(binPath);
                            DebugLogger.info('✅ [FFmpegInstallation] Trovato FFmpeg in winget: $binPath');
                            break;
                          }
                        }
                      } catch (e) {
                        // Ignora errori di ricerca ricorsiva
                      }
                    }
                  }
                }
              }
            } catch (e) {
              // Ignora errori di lettura directory
            }
          }
        }
        
        // Verifica se FFmpeg è già nel PATH
        bool foundInPath = false;
        for (final commonPath in commonPaths) {
          if (pathEnv.contains(commonPath)) {
            foundInPath = true;
            break;
          }
        }
        
        // Se non trovato nel PATH, prova a verificare direttamente nei percorsi comuni
        if (!foundInPath) {
          for (final commonPath in commonPaths) {
            final ffmpegPath = '$commonPath\\ffmpeg.exe';
            final ffmpegFile = File(ffmpegPath);
            if (await ffmpegFile.exists()) {
              // FFmpeg esiste ma non è nel PATH, prova a eseguirlo con path completo
              try {
                final result = await Process.run(ffmpegPath, ['-version']);
                if (result.exitCode == 0) {
                  DebugLogger.info('✅ [FFmpegInstallation] FFmpeg trovato in: $commonPath');
                  return true;
                }
              } catch (e) {
                // Continua a cercare
              }
            }
          }
        }
      }
      
      // Prova con comando standard (dovrebbe funzionare se FFmpeg è nel PATH)
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
  
  /// Ottiene la versione di FFmpeg installata (se disponibile)
  static Future<String?> getFFmpegVersion() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // Estrai versione dalla prima riga (es: "ffmpeg version 6.0.2")
        final match = RegExp(r'ffmpeg version (\S+)').firstMatch(output);
        return match?.group(1);
      }
    } catch (e) {
      // Ignora errori
    }
    return null;
  }
  
  /// Verifica se FFmpeg è installato e restituisce informazioni dettagliate
  static Future<FFmpegStatus> checkFFmpegStatus() async {
    final isInstalled = await isFFmpegInstalled();
    if (isInstalled) {
      final version = await getFFmpegVersion();
      return FFmpegStatus(
        isInstalled: true,
        version: version,
        path: await _findFFmpegPath(),
      );
    }
    
    return FFmpegStatus(
      isInstalled: false,
      version: null,
      path: null,
    );
  }
  
  /// Trova il path di FFmpeg (se installato)
  static Future<String?> _findFFmpegPath() async {
    try {
      if (Platform.isWindows) {
        // Windows: prova a trovare ffmpeg.exe
        final result = await Process.run('where', ['ffmpeg']);
        if (result.exitCode == 0) {
          final paths = result.stdout.toString().trim().split('\n');
          if (paths.isNotEmpty) {
            return paths.first.trim();
          }
        }
      } else {
        // macOS/Linux: usa which
        final result = await Process.run('which', ['ffmpeg']);
        if (result.exitCode == 0) {
          return result.stdout.toString().trim();
        }
      }
    } catch (e) {
      // Ignora errori
    }
    return null;
  }
  
  /// Download e installazione automatica di FFmpeg
  /// Restituisce il path di installazione o null se fallisce
  static Future<String?> installFFmpeg({
    Function(String message)? onProgress,
  }) async {
    try {
      if (Platform.isWindows) {
        return await _installFFmpegWindows(onProgress: onProgress);
      } else if (Platform.isMacOS) {
        return await _installFFmpegMacOS(onProgress: onProgress);
      } else {
        throw UnsupportedError('Installazione automatica non supportata per questa piattaforma');
      }
    } catch (e) {
      if (kDebugMode) {
        DebugLogger.error('❌ [FFmpegInstallation] Errore installazione: $e');
      }
      return null;
    }
  }
  
  /// Installazione FFmpeg su Windows usando winget
  static Future<String?> _installFFmpegWindows({
    Function(String message)? onProgress,
  }) async {
    // Prova prima con winget (metodo più semplice e affidabile)
    return await _installFFmpegWindowsWinget(onProgress: onProgress) ??
           await _installFFmpegWindowsManual(onProgress: onProgress);
  }
  
  /// Installazione FFmpeg su Windows usando winget (metodo preferito)
  static Future<String?> _installFFmpegWindowsWinget({
    Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('Verifica winget disponibilità...');
      
      // Verifica se winget è disponibile
      final wingetCheck = await Process.run('winget', ['--version']);
      if (wingetCheck.exitCode != 0) {
        DebugLogger.warning('⚠️ [FFmpegInstallation] winget non disponibile');
        return null; // Fallback a installazione manuale
      }
      
      onProgress?.call('Installazione FFmpeg tramite winget...');
      
      // Esegui winget install gyan.FFmpeg
      // Usa --silent per installazione non interattiva
      // --accept-package-agreements e --accept-source-agreements per accettare automaticamente
      final installResult = await Process.run(
        'winget',
        [
          'install',
          '--id', 'gyan.FFmpeg',
          '--silent',
          '--accept-package-agreements',
          '--accept-source-agreements',
        ],
      );
      
      if (installResult.exitCode == 0) {
        onProgress?.call('FFmpeg installato con successo!');
        
        // Attendi un momento per permettere a winget di aggiornare il PATH
        await Future.delayed(const Duration(seconds: 2));
        
        // Verifica che FFmpeg sia ora disponibile
        final ffmpegCheck = await Process.run('ffmpeg', ['-version']);
        if (ffmpegCheck.exitCode == 0) {
          final path = await _findFFmpegPath();
          onProgress?.call('FFmpeg installato e disponibile nel PATH');
          return path;
        } else {
          onProgress?.call('FFmpeg installato. Riavvia l\'app per applicare le modifiche al PATH.');
          // Restituisci path standard di winget per FFmpeg
          // winget installa tipicamente in Program Files
          return r'C:\Program Files\ffmpeg\bin';
        }
      } else {
        final errorOutput = installResult.stderr.toString();
        DebugLogger.warning('⚠️ [FFmpegInstallation] winget install fallito: $errorOutput');
        return null; // Fallback a installazione manuale
      }
    } catch (e) {
      DebugLogger.warning('⚠️ [FFmpegInstallation] Errore installazione winget: $e');
      return null; // Fallback a installazione manuale
    }
  }
  
  /// Installazione FFmpeg su Windows manuale (fallback se winget non disponibile)
  static Future<String?> _installFFmpegWindowsManual({
    Function(String message)? onProgress,
  }) async {
    onProgress?.call('Download FFmpeg per Windows...');
    
    // URL download FFmpeg Windows (ultima versione essenziale)
    // Usa gyan.dev che fornisce build precompilate
    const downloadUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
    
    // Directory di installazione (AppData locale per l'utente)
    final appDataDir = Platform.environment['LOCALAPPDATA'] ?? 
                      Platform.environment['APPDATA'] ?? 
                      '${Platform.environment['USERPROFILE']}\\AppData\\Local';
    final installDir = Directory('$appDataDir\\MyTeam\\ffmpeg');
    final binDir = Directory('${installDir.path}\\bin');
    
    // Crea directory se non esiste
    if (!await installDir.exists()) {
      await installDir.create(recursive: true);
    }
    
    // Verifica se già installato
    final ffmpegExe = File('${binDir.path}\\ffmpeg.exe');
    if (await ffmpegExe.exists()) {
      onProgress?.call('FFmpeg già installato');
      return binDir.path;
    }
    
    // Download file ZIP
    onProgress?.call('Download in corso...');
    final tempDir = await getTemporaryDirectory();
    final zipFile = File('${tempDir.path}\\ffmpeg.zip');
    
    final dio = Dio();
    await dio.download(
      downloadUrl,
      zipFile.path,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final percent = (received / total * 100).toStringAsFixed(1);
          onProgress?.call('Download: $percent%');
        }
      },
    );
    
    // Estrai ZIP
    onProgress?.call('Estrazione file...');
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    // Trova la directory principale (di solito "ffmpeg-6.x.x-essentials")
    String? rootDirName;
    for (final file in archive) {
      if (file.isFile && file.name.contains('ffmpeg.exe')) {
        final parts = file.name.split('/');
        if (parts.length > 1) {
          rootDirName = parts[0];
          break;
        }
      }
    }
    
    if (rootDirName == null) {
      throw Exception('Struttura ZIP non riconosciuta');
    }
    
    // Estrai solo i file necessari (bin/)
    for (final file in archive) {
      if (file.isFile && file.name.startsWith('$rootDirName/bin/')) {
        final relativePath = file.name.substring('$rootDirName/bin/'.length);
        final targetFile = File('${binDir.path}\\$relativePath');
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes(file.content as List<int>);
      }
    }
    
    // Pulisci file temporaneo
    await zipFile.delete();
    
    // Verifica installazione
    if (!await ffmpegExe.exists()) {
      throw Exception('FFmpeg non trovato dopo installazione');
    }
    
    onProgress?.call('FFmpeg installato con successo');
    
    return binDir.path;
  }
  
  /// Installazione FFmpeg su macOS (usa Homebrew se disponibile)
  static Future<String?> _installFFmpegMacOS({
    Function(String message)? onProgress,
  }) async {
    // Verifica se Homebrew è installato
    try {
      final brewCheck = await Process.run('brew', ['--version']);
      if (brewCheck.exitCode == 0) {
        onProgress?.call('Installazione FFmpeg con Homebrew...');
        final installResult = await Process.run('brew', ['install', 'ffmpeg']);
        if (installResult.exitCode == 0) {
          onProgress?.call('FFmpeg installato con successo');
          // Homebrew installa in /opt/homebrew/bin o /usr/local/bin
          final homebrewPath = '/opt/homebrew/bin/ffmpeg';
          if (await File(homebrewPath).exists()) {
            return '/opt/homebrew/bin';
          }
          return '/usr/local/bin';
        }
      }
    } catch (e) {
      // Homebrew non disponibile, usa download manuale
    }
    
    // Fallback: download manuale (più complesso su macOS)
    throw UnsupportedError('Installazione automatica su macOS richiede Homebrew. Installa Homebrew o FFmpeg manualmente.');
  }
  
  /// Aggiunge FFmpeg al PATH (solo per la sessione corrente)
  /// Per modifiche permanenti, l'utente deve farlo manualmente
  static Future<bool> addToPathTemporary(String ffmpegBinPath) async {
    try {
      // Aggiungi al PATH della sessione corrente
      final currentPath = Platform.environment['PATH'] ?? '';
      if (!currentPath.contains(ffmpegBinPath)) {
        final newPath = Platform.isWindows
            ? '$currentPath;$ffmpegBinPath'
            : '$currentPath:$ffmpegBinPath';
        Platform.environment['PATH'] = newPath;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Tenta di aggiungere FFmpeg al PATH permanentemente
  /// Restituisce true se riuscito, false se richiede intervento manuale
  static Future<bool> addToPathPermanently(String ffmpegBinPath) async {
    try {
      if (Platform.isWindows) {
        // Windows: usa setx (richiede permessi)
        final currentPath = Platform.environment['Path'] ?? '';
        if (!currentPath.contains(ffmpegBinPath)) {
          final newPath = '$currentPath;$ffmpegBinPath';
          final result = await Process.run('setx', ['Path', newPath]);
          if (result.exitCode == 0) {
            // setx modifica solo le variabili utente, non di sistema
            // Richiede riavvio del terminale/app per essere effettivo
            return true;
          }
        }
        return true; // Già nel PATH
      } else if (Platform.isMacOS) {
        // macOS: aggiungi a ~/.zshrc o ~/.bash_profile
        final homeDir = Platform.environment['HOME'] ?? '';
        final shellConfig = File('$homeDir/.zshrc');
        if (!await shellConfig.exists()) {
          final bashProfile = File('$homeDir/.bash_profile');
          if (await bashProfile.exists()) {
            await bashProfile.writeAsString(
              '\nexport PATH="$ffmpegBinPath:\$PATH"\n',
              mode: FileMode.append,
            );
            return true;
          }
        } else {
          await shellConfig.writeAsString(
            '\nexport PATH="$ffmpegBinPath:\$PATH"\n',
            mode: FileMode.append,
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      DebugLogger.warning('⚠️ [FFmpegInstallation] Errore aggiunta PATH: $e');
      return false;
    }
  }
  
  /// Ottiene istruzioni per installazione manuale
  static String getManualInstallationInstructions() {
    if (Platform.isWindows) {
      return '''
FFmpeg non è installato. Per installarlo:

1. Scarica FFmpeg da: https://www.gyan.dev/ffmpeg/builds/
   - Scegli "ffmpeg-release-essentials.zip"

2. Estrai l'archivio in una cartella (es: C:\\ffmpeg)

3. Aggiungi al PATH:
   - Apri "Sistema > Impostazioni avanzate > Variabili d'ambiente"
   - Aggiungi C:\\ffmpeg\\bin alla variabile "Path"
   - Riavvia l'applicazione

4. Verifica: apri PowerShell e esegui "ffmpeg -version"
''';
    } else if (Platform.isMacOS) {
      return '''
FFmpeg non è installato. Per installarlo:

1. Installa Homebrew (se non già installato):
   /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

2. Installa FFmpeg:
   brew install ffmpeg

3. Verifica: esegui "ffmpeg -version" nel terminale
''';
    }
    return 'FFmpeg non è installato. Consulta https://ffmpeg.org/download.html per istruzioni.';
  }
}

/// Stato di installazione FFmpeg
class FFmpegStatus {
  final bool isInstalled;
  final String? version;
  final String? path;
  
  FFmpegStatus({
    required this.isInstalled,
    this.version,
    this.path,
  });
  
  @override
  String toString() {
    if (isInstalled) {
      return 'FFmpeg installato${version != null ? " (v$version)" : ""}${path != null ? " in $path" : ""}';
    }
    return 'FFmpeg non installato';
  }
}

