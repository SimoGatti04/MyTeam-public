import 'package:flutter/material.dart';

import '../../../core/services/updater/models/update_state.dart';

/// Persistent but low-emphasis updater status shown in Settings.
class UpdateSettingsStatus extends StatelessWidget {
  final UpdateState state;
  final VoidCallback onRetry;

  const UpdateSettingsStatus({
    super.key,
    required this.state,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String message)? status =
        switch (state.status) {
          UpdateStatus.checking => (
            Icons.sync,
            Colors.blue,
            'Verifica disponibilità in corso...',
          ),
          UpdateStatus.upToDate => (
            Icons.check_circle_outline,
            Colors.green,
            'L\'applicazione è aggiornata',
          ),
          UpdateStatus.updateAvailable => (
            Icons.system_update,
            Colors.blue,
            'Aggiornamento disponibile: ${state.manifest?.versionName ?? ''}',
          ),
          UpdateStatus.failed => (
            state.failureKind == UpdateFailureKind.security
                ? Icons.gpp_bad_outlined
                : Icons.info_outline,
            state.failureKind == UpdateFailureKind.security
                ? Colors.red
                : Colors.blueGrey,
            state.errorMessage ?? 'Controllo aggiornamenti non riuscito.',
          ),
          _ => null,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(status.$1, color: status.$2, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.$3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: status.$2, fontSize: 13),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(
              state.status == UpdateStatus.failed
                  ? 'Riprova'
                  : 'Controlla aggiornamenti ora',
            ),
            onPressed:
                state.status == UpdateStatus.checking ||
                    state.status == UpdateStatus.downloading ||
                    state.status == UpdateStatus.verifying ||
                    state.status == UpdateStatus.installing
                ? null
                : onRetry,
          ),
        ),
      ],
    );
  }
}
