import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/debug_logger.dart';
import '../../core/services/settings_service.dart';

/// Overlay per mostrare i log in modalità debug
/// Si nasconde automaticamente quando debug mode è disattivato
class DebugLogOverlay extends StatefulWidget {
  const DebugLogOverlay({super.key});

  @override
  State<DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends State<DebugLogOverlay> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];
  bool _isMinimized = false;
  
  @override
  void initState() {
    super.initState();
    // Carica log solo se debug mode è attivo
    // Usa la stessa logica di DebugLogger._isDebugModeActive
    final isDebugModeActive = SettingsService.isInitialized 
        ? SettingsService.getDebugModeStatic()
        : kDebugMode;
    if (isDebugModeActive) {
      _logs.addAll(DebugLogger.getLogs());
      DebugLogger.addListener(_onNewLog);
    }
  }
  
  @override
  void dispose() {
    DebugLogger.removeListener(_onNewLog);
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Aggiorna listener quando SettingsService cambia
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    // Priorità: se SettingsService è inizializzato, usa solo il toggle (ignora kDebugMode)
    final isDebugModeActive = SettingsService.isInitialized
        ? settingsService.getDebugMode()
        : kDebugMode;
    
    if (isDebugModeActive) {
      // Se debug mode è attivo, assicurati che il listener sia registrato
      // e carica i log esistenti se necessario
      final existingLogs = DebugLogger.getLogs();
      if (_logs.length != existingLogs.length || 
          (_logs.isNotEmpty && existingLogs.isNotEmpty && _logs.first != existingLogs.first)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _logs.clear();
              _logs.addAll(existingLogs);
            });
          }
        });
      }
      // Aggiungi listener se non è già presente (evita duplicati)
      // Nota: non possiamo controllare facilmente se è già presente,
      // ma removeListener è idempotente
      DebugLogger.removeListener(_onNewLog);
      DebugLogger.addListener(_onNewLog);
    } else {
      // Se debug mode è disattivo, rimuovi listener e pulisci log
      DebugLogger.removeListener(_onNewLog);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _logs.clear();
            });
          }
        });
      }
    }
  }
  
  void _onNewLog(String log) {
    // Ignora log se debug mode non è attivo
    // Usa la stessa logica di DebugLogger._isDebugModeActive
    final isDebugModeActive = SettingsService.isInitialized
        ? SettingsService.getDebugModeStatic()
        : kDebugMode;
    if (!isDebugModeActive) {
      return;
    }
    
    if (mounted) {
      // Posticipa setState() se siamo durante il build phase
      // Questo evita errori "setState() called during build"
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            if (log.isNotEmpty) {
              _logs.add(log);
              // Mantieni solo gli ultimi 500 log
              if (_logs.length > 500) {
                _logs.removeAt(0);
              }
            } else {
              // Clear signal
              _logs.clear();
            }
          });
          
          // Auto-scroll all'ultimo log (dopo setState)
          if (_scrollController.hasClients && !_isMinimized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Usa Consumer per reagire ai cambiamenti di SettingsService
    return Consumer<SettingsService>(
      builder: (context, settingsService, child) {
        // Priorità: se SettingsService è inizializzato, usa solo il toggle (ignora kDebugMode)
        // Se non è inizializzato, usa kDebugMode come fallback
        final isDebugModeActive = SettingsService.isInitialized
            ? settingsService.getDebugMode()
            : kDebugMode;
        if (!isDebugModeActive) {
          return const SizedBox.shrink();
        }
        
        return _buildOverlay();
      },
    );
  }
  
  Widget _buildOverlay() {
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isMinimized = !_isMinimized;
          });
        },
        child: Container(
          height: _isMinimized ? 40 : 200,
          decoration: BoxDecoration(
            color: Colors.black87,
            border: Border(
              top: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _isMinimized ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Debug Logs',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_logs.length} logs',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      color: Colors.white70,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        final allLogs = _logs.join('\n');
                        Clipboard.setData(ClipboardData(text: allLogs));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Logs copiati negli appunti'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Copy all logs',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      color: Colors.white70,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        DebugLogger.clear();
                      },
                      tooltip: 'Clear logs',
                    ),
                  ],
                ),
              ),
              // Logs
              if (!_isMinimized)
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(4),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      Color? textColor = Colors.white70;
                      
                      // Colore basato su livello
                      if (log.contains('[ERROR]')) {
                        textColor = Colors.red[300];
                      } else if (log.contains('[WARN]')) {
                        textColor = Colors.orange[300];
                      } else if (log.contains('[DEBUG]')) {
                        textColor = Colors.blue[300];
                      }
                      
                      return InkWell(
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(text: log));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Log copiato negli appunti'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                          child: SelectableText(
                            log,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

