import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/ffmpeg_installation_service.dart';

/// Dialog per installazione guidata FFmpeg
class FFmpegInstallationDialog extends StatefulWidget {
  const FFmpegInstallationDialog({super.key});

  @override
  State<FFmpegInstallationDialog> createState() => _FFmpegInstallationDialogState();
}

class _FFmpegInstallationDialogState extends State<FFmpegInstallationDialog> {
  bool _isInstalling = false;
  String _installationStatus = '';
  String? _installedPath;
  bool _installationSuccess = false;
  bool _installationFailed = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('FFmpeg Richiesto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FFmpeg è necessario per la compressione video su Windows.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            if (!_isInstalling && !_installationSuccess && !_installationFailed) ...[
              // Opzioni iniziali
              const Text(
                'Scegli un\'opzione:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              // Bottone installazione automatica
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startAutomaticInstallation(),
                  icon: const Icon(Icons.download),
                  label: const Text('Installa Automaticamente'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Bottone istruzioni manuali
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showManualInstructions(),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Istruzioni Manuali'),
                ),
              ),
            ],
            
            if (_isInstalling) ...[
              // Stato installazione
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _installationStatus.isNotEmpty ? _installationStatus : 'Installazione in corso...',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            
            if (_installationSuccess) ...[
              // Successo
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              const Text(
                'FFmpeg installato con successo!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              if (_installedPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Path: $_installedPath',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Nota: Potrebbe essere necessario riavviare l\'app per usare FFmpeg.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
            
            if (_installationFailed) ...[
              // Errore
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Installazione fallita',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Puoi provare l\'installazione manuale seguendo le istruzioni.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isInstalling && !_installationSuccess) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
        ],
        if (_installationSuccess || _installationFailed) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ],
    );
  }

  Future<void> _startAutomaticInstallation() async {
    setState(() {
      _isInstalling = true;
      _installationStatus = 'Verifica sistema...';
    });

    try {
      final installedPath = await FFmpegInstallationService.installFFmpeg(
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _installationStatus = message;
            });
          }
        },
      );

      if (installedPath != null) {
        // Tenta di aggiungere al PATH temporaneo (per questa sessione)
        await FFmpegInstallationService.addToPathTemporary(installedPath);
        
        // Tenta di aggiungere al PATH permanente (può fallire senza permessi)
        final pathAdded = await FFmpegInstallationService.addToPathPermanently(installedPath);
        
        setState(() {
          _isInstalling = false;
          _installationSuccess = true;
          _installedPath = installedPath;
          _installationStatus = pathAdded
              ? 'FFmpeg installato e aggiunto al PATH'
              : 'FFmpeg installato. Potrebbe essere necessario aggiungerlo manualmente al PATH.';
        });
      } else {
        throw Exception('Installazione fallita: path non restituito');
      }
    } catch (e) {
      setState(() {
        _isInstalling = false;
        _installationFailed = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _showManualInstructions() {
    final instructions = FFmpegInstallationService.getManualInstallationInstructions();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Istruzioni Installazione Manuale'),
        content: SingleChildScrollView(
          child: Text(instructions),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copia istruzioni negli appunti
              Clipboard.setData(ClipboardData(text: instructions));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Istruzioni copiate negli appunti')),
              );
            },
            child: const Text('Copia'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }
}

