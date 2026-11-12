import '../../../../features/upload/viewmodels/upload_viewmodel.dart';
import '../../services/debug_logger.dart';

/// Guardia per verificare che non vi siano compressioni, upload, finalizzazioni o code in corso,
/// né che lo stato dei task salvati sia non ancora inizializzato o fallito,
/// prima di consentire l'avvio dell'installazione dell'aggiornamento.
class ActiveTasksGuard {
  final UploadViewModel? _uploadViewModel;

  ActiveTasksGuard({
    UploadViewModel? uploadViewModel,
  }) : _uploadViewModel = uploadViewModel;

  /// Restituisce l'istanza di UploadViewModel associata alla guardia, se presente.
  UploadViewModel? get uploadViewModel => _uploadViewModel;

  /// Restituisce true se sono presenti operazioni critiche attive o se lo stato non è ancora certo.
  /// SICUREZZA FAIL-CLOSED:
  /// 1. Se _uploadViewModel non è fornito: fail-closed -> true.
  /// 2. Se _uploadViewModel non ha completato con successo l'inizializzazione dei task: fail-closed -> true.
  /// 3. Se l'inizializzazione ha restituito errore: fail-closed -> true.
  /// 4. Se l'installer è già stato avviato: fail-closed -> true.
  /// 5. Se vi sono operazioni attive (compressione, upload, coda, task pendenti): fail-closed -> true.
  bool get hasActiveOperations {
    final vm = _uploadViewModel;
    if (vm == null) {
      DebugLogger.warning('ActiveTasksGuard: UploadViewModel non disponibile. Fail-closed: installazione non autorizzata.');
      return true;
    }

    if (!vm.isInitialized) {
      DebugLogger.warning('ActiveTasksGuard: UploadViewModel non ancora inizializzato o in caricamento. Fail-closed: installazione non autorizzata.');
      return true;
    }

    if (vm.initError != null) {
      DebugLogger.warning('ActiveTasksGuard: Inizializzazione UploadViewModel fallita (${vm.initError}). Fail-closed: installazione non autorizzata.');
      return true;
    }

    if (vm.isInstallationInProgress) {
      DebugLogger.warning('ActiveTasksGuard: Transizione installer in corso. Nuove installazioni bloccate.');
      return true;
    }

    final isCompressing = vm.isCompressing;
    final isUploading = vm.isUploading;
    final isProcessing = vm.isProcessingQueue;
    final hasQueue = vm.queueLength > 0;
    final hasActiveTaskInList = vm.hasActiveTasks;

    return isCompressing || isUploading || isProcessing || hasQueue || hasActiveTaskInList;
  }

  /// Tenta di acquisire il lock per l'installazione in modo atomico.
  /// Restituisce true se il lock è stato acquisito con successo.
  bool acquireInstallationLock() {
    final vm = _uploadViewModel;
    if (vm == null) return false;
    return vm.acquireInstallationLock();
  }

  /// Rilascia il lock dell'installazione
  void releaseInstallationLock() {
    _uploadViewModel?.releaseInstallationLock();
  }

  /// Descrizione user-facing delle operazioni in corso che bloccano l'aggiornamento
  String? get activeOperationsDescription {
    final vm = _uploadViewModel;
    if (vm == null) {
      return 'Stato dei caricamenti non ancora disponibile. Impossibile garantire la sicurezza dei file.';
    }

    if (vm.initError != null) {
      return "Errore durante la verifica dei file locali: ${vm.initError}. Riavvia l'applicazione prima di aggiornare.";
    }

    if (!vm.isInitialized) {
      return 'Inizializzazione dei caricamenti e verifica dei file in corso... Riprova tra pochi istanti.';
    }

    if (vm.isInstallationInProgress) {
      return 'Installazione già avviata o passaggio al sistema operativo in corso.';
    }

    final isCompressing = vm.isCompressing;
    final isUploading = vm.isUploading;
    final isProcessing = vm.isProcessingQueue;
    final hasQueue = vm.queueLength > 0;
    final hasActiveTaskInList = vm.hasActiveTasks;

    if (isCompressing && isUploading) {
      return 'Compressione video e caricamento verso il server in corso. Attendi il completamento prima di aggiornare.';
    } else if (isCompressing) {
      return "Compressione video in corso. L'aggiornamento dell'applicazione interromperebbe l'elaborazione.";
    } else if (isUploading) {
      return 'Caricamento video verso il server in corso. Attendi il completamento del caricamento.';
    } else if (isProcessing || hasQueue || hasActiveTaskInList) {
      return 'Coda di caricamento attiva con elementi in attesa o in elaborazione.';
    }

    return null;
  }
}
