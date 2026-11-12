import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/services/settings_service.dart';
import '../../../core/services/debug_logger.dart';
import '../../../core/services/updater/update_service.dart';
import '../../widgets/updater/update_settings_status.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _debugMode = false;
  bool _hardwareDecoding = false;
  bool _isLoading = true;
  String _appVersion = '0.1.0 (1)';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await SettingsService.initialize();
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version} (${info.buildNumber})';
    } catch (_) {}

    setState(() {
      _debugMode = SettingsService.getDebugModeStatic();
      _hardwareDecoding = SettingsService.getHardwareDecodingStatic();
      _isLoading = false;
    });
  }

  Future<void> _toggleDebugMode(bool value) async {
    setState(() {
      _debugMode = value;
    });
    await SettingsService.setDebugModeStatic(value);
    if (!value) {
      DebugLogger.clearLogsOnDebugModeDisabled();
    } else {
      DebugLogger.info('Debug mode enabled');
    }
  }

  Future<void> _toggleHardwareDecoding(bool value) async {
    setState(() {
      _hardwareDecoding = value;
    });
    await SettingsService.setHardwareDecodingStatic(value);
    DebugLogger.info('Hardware decoding ${value ? "enabled" : "disabled"}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
        title: const Text('Settings'),
      ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final updateService = context.watch<UpdateService>();
    final updateState = updateService.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sezione Aggiornamenti Software Autonomi
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.system_update, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        updateService.isQaChannel
                            ? 'Aggiornamenti Software · CANALE QA'
                            : 'Aggiornamenti Software',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Versione installata: $_appVersion',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'MyTeam verifica e scarica gli aggiornamenti in modo autonomo e sicuro senza ricorrere a store esterni.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  UpdateSettingsStatus(
                    state: updateState,
                    onRetry: () => updateService.checkForUpdates(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Debug Mode Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debug',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Debug Mode'),
                    subtitle: const Text(
                      'Show debug logs in an overlay at the bottom of the screen',
                    ),
                    value: _debugMode,
                    onChanged: _toggleDebugMode,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Performance Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Performance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Hardware Decoding'),
                    subtitle: const Text(
                      'Use hardware acceleration for video decoding (may cause issues on some systems)',
                    ),
                    value: _hardwareDecoding,
                    onChanged: _toggleHardwareDecoding,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
