import 'package:flutter/material.dart';
import '../../../core/services/updater/update_service.dart';
import '../../../core/services/updater/models/update_state.dart';

/// Widget compatto da mostrare in Home o nelle Impostazioni quando è disponibile un aggiornamento
class UpdateBannerWidget extends StatelessWidget {
  final UpdateService updateService;

  const UpdateBannerWidget({
    super.key,
    required this.updateService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updateService,
      builder: (context, _) {
        final state = updateService.state;

        if (state.status == UpdateStatus.idle ||
            state.status == UpdateStatus.upToDate ||
            (state.status == UpdateStatus.failed &&
                state.failureKind == UpdateFailureKind.serviceUnavailable)) {
          return const SizedBox.shrink();
        }

        if (state.status == UpdateStatus.checking) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.withValues(alpha: 0.1),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Verifica aggiornamenti in corso...'),
              ],
            ),
          );
        }

        if (state.status == UpdateStatus.updateAvailable) {
          final manifest = state.manifest;
          return Card(
            margin: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.system_update, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nuova versione disponibile: ${manifest?.versionName ?? ""} (build ${manifest?.versionCode ?? ""})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  if (manifest?.changelog != null && manifest!.changelog.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      manifest.changelog,
                      style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Scarica e aggiorna'),
                        onPressed: () => updateService.downloadUpdate(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        if (state.status == UpdateStatus.downloading) {
          final percent = (state.progress * 100).toStringAsFixed(0);
          final mbDownloaded = (state.downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal = (state.totalBytes / (1024 * 1024)).toStringAsFixed(1);

          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Download aggiornamento: $percent% ($mbDownloaded MB / $mbTotal MB)'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: state.progress > 0 ? state.progress : null),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => updateService.cancelDownload(),
                      child: const Text('Annulla'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.status == UpdateStatus.verifying) {
          return const Card(
            margin: EdgeInsets.all(12),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Verifica crittografica dell\'integrità (SHA-256)...'),
                ],
              ),
            ),
          );
        }

        if (state.status == UpdateStatus.readyToInstall) {
          return Card(
            margin: const EdgeInsets.all(12),
            color: Colors.green.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.green.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 10),
                      Text(
                        'Aggiornamento pronto per l\'installazione',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Il pacchetto è stato scaricato e verificato con successo. Procedere con l\'installazione?'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.install_mobile),
                        label: const Text('Installa ora'),
                        onPressed: () => updateService.triggerInstallation(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        if (state.status == UpdateStatus.installing) {
          return Card(
            margin: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.blue.shade300),
            ),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Avvio dell'installer di sistema in corso...",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.status == UpdateStatus.handoffToSystemInstaller) {
          return Card(
            margin: const EdgeInsets.all(12),
            color: Colors.teal.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.teal.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.system_update_alt, color: Colors.teal),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Passaggio all'installer di sistema completato",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Segui le istruzioni sul dispositivo per completare l'installazione. Se hai annullato l'installazione, puoi tornare a utilizzare l'app.",
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => updateService.resetAfterCancelledInstall(),
                      child: const Text("Torna all'app / Annulla"),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.status == UpdateStatus.blockedByActiveTasks) {
          return Card(
            margin: const EdgeInsets.all(12),
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.amber.shade400),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      SizedBox(width: 10),
                      Text(
                        'Installazione posticipata',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(state.activeTasksDescription ?? 'Operazioni critiche in corso.'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => updateService.triggerInstallation(),
                        child: const Text('Riprova installazione'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        if (state.status == UpdateStatus.failed) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage ?? 'Errore durante l\'aggiornamento.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => updateService.checkForUpdates(),
                      child: const Text('Riprova'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
