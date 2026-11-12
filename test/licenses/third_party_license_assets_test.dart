import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const noticeSha256 = <String, String>{
    'assets/licenses/ffmpeg_kit_flutter_new/LICENSE':
        'da7eabb7bafdf7d3ae5e9f223aa5bdc1eece45ac569dc21b3b037520b4464768',
    'assets/licenses/ffmpeg_kit_flutter_new/LICENSE.GPLv3':
        '8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903',
    'assets/licenses/media_kit_libs_windows_video/LICENSE':
        '2e3000f38718f050869d57540c288c661a446f64df1ba4ea4764df552b04a331',
  };

  test('third-party notice files match verified upstream package bytes', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('    - assets/licenses/ffmpeg_kit_flutter_new/'));
    expect(pubspec, contains('    - assets/licenses/media_kit_libs_windows_video/'));
    for (final entry in noticeSha256.entries) {
      final bytes = File(entry.key).readAsBytesSync();
      expect(sha256.convert(bytes).toString(), entry.value, reason: entry.key);
    }
  });

  test('Windows installer installs project and package notices readably', () {
    final installer = File('windows/installer/MyTeam-Setup.iss').readAsStringSync();
    expect(installer, contains('Source: "..\\..\\LICENSE"; DestDir: "{app}\\licenses"'));
    expect(installer, contains('Source: "..\\..\\assets\\licenses\\*"; DestDir: "{app}\\licenses"'));
  });
}
