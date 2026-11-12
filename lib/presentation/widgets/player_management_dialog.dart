import 'package:flutter/material.dart';
import '../../../domain/entities/player.dart';
import '../../../data/datasources/remote/player_remote_datasource.dart';
import '../../../core/network/api_client.dart';

/// Dialog per gestire giocatori associati a un video
class PlayerManagementDialog extends StatefulWidget {
  final String videoId;
  final List<String> currentPlayerIds;
  
  const PlayerManagementDialog({
    super.key,
    required this.videoId,
    required this.currentPlayerIds,
  });
  
  @override
  State<PlayerManagementDialog> createState() => _PlayerManagementDialogState();
}

class _PlayerManagementDialogState extends State<PlayerManagementDialog> {
  late PlayerRemoteDataSource _dataSource;
  List<Player> _allPlayers = [];
  List<String> _selectedPlayerIds = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _dataSource = PlayerRemoteDataSource(ApiClient());
    _selectedPlayerIds = List.from(widget.currentPlayerIds);
    _loadPlayers();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPlayers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final players = await _dataSource.getPlayers();
      setState(() {
        _allPlayers = players;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _editPlayer(Player player) async {
    final nameController = TextEditingController(text: player.name);
    final descriptionController = TextEditingController(text: player.description ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica Giocatore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrizione (opzionale)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    
    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final updatedPlayer = await _dataSource.updatePlayer(
          id: player.id,
          name: nameController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );
        
        setState(() {
          final index = _allPlayers.indexWhere((p) => p.id == player.id);
          if (index != -1) {
            _allPlayers[index] = updatedPlayer;
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Giocatore aggiornato'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore aggiornamento giocatore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    nameController.dispose();
    descriptionController.dispose();
  }
  
  Future<void> _deletePlayer(Player player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Giocatore'),
        content: Text(
          'Sei sicuro di voler eliminare "${player.name}"?\n\n'
          'Questa azione non può essere annullata. Il giocatore verrà rimosso da tutti i video associati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _dataSource.deletePlayer(player.id);
        
        setState(() {
          _allPlayers.removeWhere((p) => p.id == player.id);
          _selectedPlayerIds.remove(player.id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Giocatore eliminato'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore eliminazione giocatore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  Future<void> _createPlayer() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuovo Giocatore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrizione (opzionale)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    
    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final newPlayer = await _dataSource.createPlayer(
          name: nameController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );
        
        setState(() {
          _allPlayers.add(newPlayer);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Giocatore creato'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore creazione giocatore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    nameController.dispose();
    descriptionController.dispose();
  }
  
  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Rimuovi giocatori non più selezionati
      for (final playerId in widget.currentPlayerIds) {
        if (!_selectedPlayerIds.contains(playerId)) {
          try {
            await _dataSource.removePlayerFromVideo(widget.videoId, playerId);
          } catch (e) {
            // Ignora 404 - il giocatore potrebbe essere già stato rimosso o eliminato
            // Questo può succedere se un giocatore è stato eliminato mentre il dialog era aperto
            if (!e.toString().contains('404') && !e.toString().contains('not found')) {
              rethrow; // Rilancia se non è un errore 404
            }
          }
        }
      }
      
      // Aggiungi nuovi giocatori selezionati
      for (final playerId in _selectedPlayerIds) {
        if (!widget.currentPlayerIds.contains(playerId)) {
          // Verifica che il giocatore esista ancora nella lista
          if (_allPlayers.any((p) => p.id == playerId)) {
            await _dataSource.addPlayerToVideo(widget.videoId, playerId);
          }
        }
      }
      
      if (mounted) {
        Navigator.of(context).pop(true); // true = changes saved
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore salvataggio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final filteredPlayers = _searchController.text.isEmpty
        ? _allPlayers
        : _allPlayers.where((p) =>
            p.name.toLowerCase().contains(_searchController.text.toLowerCase())
          ).toList();
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Gestisci Giocatori',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca giocatori...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            
            // Players list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Errore: $_error'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPlayers,
                                child: const Text('Riprova'),
                              ),
                            ],
                          ),
                        )
                      : filteredPlayers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Nessun giocatore trovato'),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _createPlayer,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Crea Giocatore'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredPlayers.length,
                              itemBuilder: (context, index) {
                                final player = filteredPlayers[index];
                                final isSelected = _selectedPlayerIds.contains(player.id);
                                
                                return ListTile(
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedPlayerIds.add(player.id);
                                        } else {
                                          _selectedPlayerIds.remove(player.id);
                                        }
                                      });
                                    },
                                  ),
                                  title: Text(player.name),
                                  subtitle: player.description != null
                                      ? Text(player.description!)
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _editPlayer(player),
                                        tooltip: 'Modifica',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                        onPressed: () => _deletePlayer(player),
                                        tooltip: 'Elimina',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
            
            // Actions
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _createPlayer,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuovo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annulla'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salva'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

