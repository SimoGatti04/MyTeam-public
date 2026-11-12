import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myteam/core/services/updater/models/update_state.dart';
import 'package:myteam/presentation/widgets/updater/startup_update_notice.dart';
import 'package:myteam/presentation/widgets/updater/update_settings_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'startup unavailable notice appears once, auto-hides, and does not replay on tab navigation',
    (tester) async {
      final updater = _FakeUpdater();
      var selectedTab = 'Home';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  StartupUpdateNotice(
                    listenable: updater,
                    readState: () => updater.state,
                    checkForUpdates: updater.checkForUpdates,
                  ),
                  Text(selectedTab),
                  TextButton(
                    onPressed: () => setState(() => selectedTab = 'Settings'),
                    child: const Text('Navigate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(updater.checkCount, 1);
      expect(
        find.text(
          'Impossibile verificare gli aggiornamenti. Riproveremo più tardi.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 5),
      );

      await tester.tap(find.text('Navigate'));
      await tester.pump();
      expect(find.text('Settings'), findsOneWidget);
      expect(updater.checkCount, 1);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text(
          'Impossibile verificare gli aggiornamenti. Riproveremo più tardi.',
        ),
        findsNothing,
      );
      expect(updater.checkCount, 1);
    },
  );

  testWidgets('successful check clears an active transient startup notice', (
    tester,
  ) async {
    final updater = _FakeUpdater();
    await tester.pumpWidget(_startupApp(updater));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(
        'Impossibile verificare gli aggiornamenti. Riproveremo più tardi.',
      ),
      findsOneWidget,
    );

    updater.setState(const UpdateState(status: UpdateStatus.upToDate));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Impossibile verificare gli aggiornamenti. Riproveremo più tardi.',
      ),
      findsNothing,
    );
  });

  testWidgets('Settings keeps security failure visible and Retry invokes check', (
    tester,
  ) async {
    var retries = 0;
    const signatureFailure = UpdateState(
      status: UpdateStatus.failed,
      failureKind: UpdateFailureKind.security,
      errorMessage:
          'Firma digitale dell’aggiornamento non valida. Aggiornamento rifiutato.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateSettingsStatus(
            state: signatureFailure,
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.textContaining('Firma digitale'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    await tester.tap(find.text('Riprova'));
    expect(retries, 1);
  });
}

Widget _startupApp(_FakeUpdater updater) => MaterialApp(
  home: Scaffold(
    body: StartupUpdateNotice(
      listenable: updater,
      readState: () => updater.state,
      checkForUpdates: updater.checkForUpdates,
    ),
  ),
);

class _FakeUpdater extends ChangeNotifier {
  UpdateState state = const UpdateState();
  int checkCount = 0;

  Future<bool> checkForUpdates() async {
    checkCount++;
    setState(
      const UpdateState(
        status: UpdateStatus.failed,
        failureKind: UpdateFailureKind.serviceUnavailable,
        errorMessage: 'Servizio aggiornamenti non raggiungibile.',
      ),
    );
    return false;
  }

  void setState(UpdateState newState) {
    state = newState;
    notifyListeners();
  }
}
