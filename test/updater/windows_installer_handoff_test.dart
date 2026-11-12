import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myteam/core/services/updater/installer_service.dart';

void main() {
  group('Windows updater installer handoff', () {
    test('always requests graceful close and prevents old-app relaunch', () {
      final defaults = InstallerService.windowsInstallerArgsForTesting(null);
      final requested = InstallerService.windowsInstallerArgsForTesting([
        '/VERYSILENT',
        '/RESTARTAPPLICATIONS',
        '/SUPPRESSMSGBOXES',
      ]);

      for (final args in [defaults, requested]) {
        expect(args, contains('/CLOSEAPPLICATIONS'));
        expect(args, contains('/NOFORCECLOSEAPPLICATIONS'));
        expect(args, contains('/NORESTARTAPPLICATIONS'));
        expect(args, contains('/NORESTART'));
        expect(args, isNot(contains('/RESTARTAPPLICATIONS')));
      }
      expect(defaults, contains('/SILENT'));
      expect(requested, contains('/VERYSILENT'));
    });

    test(
      'installer is detached and setup preserves stable per-user identity',
      () {
        final installerService = File(
          'lib/core/services/updater/installer_service.dart',
        ).readAsStringSync();
        final setup = File(
          'windows/installer/MyTeam-Setup.iss',
        ).readAsStringSync();

        expect(installerService, contains('mode: ProcessStartMode.detached'));
        expect(
          setup,
          contains('AppId={{9B7E3E5C-62E8-4DA4-8FB7-F58552309AA2}'),
        );
        expect(
          setup,
          contains(r'DefaultDirName={localappdata}\Programs\{#MyAppName}'),
        );
        expect(setup, contains('PrivilegesRequired=lowest'));
        expect(setup, contains('CloseApplications=yes'));
        expect(setup, contains('RestartApplications=no'));
        expect(setup, isNot(contains('CloseApplications=no')));
        expect(setup, isNot(contains('RestartApplications=yes')));
        expect(setup, isNot(contains('[UninstallDelete]')));
        expect(setup, isNot(contains('/FORCECLOSEAPPLICATIONS')));
      },
    );
  });
}
