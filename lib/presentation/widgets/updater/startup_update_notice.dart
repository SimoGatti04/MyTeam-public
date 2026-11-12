import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/updater/models/update_state.dart';

/// Runs the one startup check and shows a single, temporary notice only when
/// that check cannot reach the update service. Kept at the Home root so tab
/// changes and rebuilds do not restart the check or replay the notice.
class StartupUpdateNotice extends StatefulWidget {
  final Listenable listenable;
  final UpdateState Function() readState;
  final Future<bool> Function() checkForUpdates;

  const StartupUpdateNotice({
    super.key,
    required this.listenable,
    required this.readState,
    required this.checkForUpdates,
  });

  @override
  State<StartupUpdateNotice> createState() => _StartupUpdateNoticeState();
}

class _StartupUpdateNoticeState extends State<StartupUpdateNotice> {
  bool _startupCheckPending = false;
  bool _startupNoticeHandled = false;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _notice;
  bool _noticeOpen = false;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onUpdateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startupCheckPending = true;
      unawaited(widget.checkForUpdates());
    });
  }

  @override
  void didUpdateWidget(covariant StartupUpdateNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onUpdateChanged);
      widget.listenable.addListener(_onUpdateChanged);
    }
  }

  void _onUpdateChanged() {
    final status = widget.readState().status;
    if (status == UpdateStatus.upToDate ||
        status == UpdateStatus.updateAvailable) {
      _closeNotice();
    }
    if (!_startupCheckPending ||
        _startupNoticeHandled ||
        status == UpdateStatus.checking ||
        status == UpdateStatus.idle) {
      return;
    }

    _startupCheckPending = false;
    _startupNoticeHandled = true;
    final state = widget.readState();
    if (status == UpdateStatus.failed &&
        state.failureKind == UpdateFailureKind.serviceUnavailable &&
        mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        final controller = messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.blueGrey.shade700,
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Impossibile verificare gli aggiornamenti. Riproveremo più tardi.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
        _notice = controller;
        _noticeOpen = true;
        controller.closed.then((_) {
          if (identical(_notice, controller)) {
            _notice = null;
            _noticeOpen = false;
          }
        });
      }
    }
  }

  void _closeNotice() {
    final controller = _notice;
    if (controller != null && _noticeOpen) {
      controller.close();
    }
    _notice = null;
    _noticeOpen = false;
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onUpdateChanged);
    _closeNotice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
