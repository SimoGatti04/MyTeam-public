import 'package:flutter/material.dart';
import '../../../domain/entities/team.dart';
import '../../../data/datasources/remote/team_remote_datasource.dart';
import '../../../core/network/api_client.dart';

/// Dialog per gestire teams associati a un video
class TeamManagementDialog extends StatefulWidget {
  final String videoId;
  final List<String> currentTeamIds;
  
  const TeamManagementDialog({
    super.key,
    required this.videoId,
    required this.currentTeamIds,
  });
  
  @override
  State<TeamManagementDialog> createState() => _TeamManagementDialogState();
}

class _TeamManagementDialogState extends State<TeamManagementDialog> {
  late TeamRemoteDataSource _dataSource;
  List<Team> _allTeams = [];
  List<String> _selectedTeamIds = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _dataSource = TeamRemoteDataSource(ApiClient());
    _selectedTeamIds = List.from(widget.currentTeamIds);
    _loadTeams();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final teams = await _dataSource.getTeams();
      setState(() {
        _allTeams = teams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _editTeam(Team team) async {
    final nameController = TextEditingController(text: team.name);
    final descriptionController = TextEditingController(text: team.description ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica Squadra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome Squadra',
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
        final updatedTeam = await _dataSource.updateTeam(
          id: team.id,
          name: nameController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );
        
        setState(() {
          final index = _allTeams.indexWhere((t) => t.id == team.id);
          if (index != -1) {
            _allTeams[index] = updatedTeam;
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Squadra aggiornata'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore aggiornamento squadra: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    nameController.dispose();
    descriptionController.dispose();
  }
  
  Future<void> _deleteTeam(Team team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Squadra'),
        content: Text(
          'Sei sicuro di voler eliminare "${team.name}"?\n\n'
          'Questa azione non può essere annullata. La squadra verrà rimossa da tutti i video associati.',
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
        await _dataSource.deleteTeam(team.id);
        
        setState(() {
          _allTeams.removeWhere((t) => t.id == team.id);
          _selectedTeamIds.remove(team.id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Squadra eliminata'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore eliminazione squadra: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  Future<void> _createTeam() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuova Squadra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome Squadra',
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
        final newTeam = await _dataSource.createTeam(
          name: nameController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );
        
        setState(() {
          _allTeams.add(newTeam);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Squadra creata'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore creazione squadra: $e'),
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
      // Rimuovi teams non più selezionati
      for (final teamId in widget.currentTeamIds) {
        if (!_selectedTeamIds.contains(teamId)) {
          try {
            await _dataSource.removeTeamFromVideo(widget.videoId, teamId);
          } catch (e) {
            // Ignora 404 - il team potrebbe essere già stato rimosso o eliminato
            if (!e.toString().contains('404') && !e.toString().contains('not found')) {
              rethrow;
            }
          }
        }
      }
      
      // Aggiungi nuovi teams selezionati
      for (final teamId in _selectedTeamIds) {
        if (!widget.currentTeamIds.contains(teamId)) {
          // Verifica che il team esista ancora nella lista
          if (_allTeams.any((t) => t.id == teamId)) {
            await _dataSource.addTeamToVideo(widget.videoId, teamId);
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
    final filteredTeams = _searchController.text.isEmpty
        ? _allTeams
        : _allTeams.where((t) =>
            t.name.toLowerCase().contains(_searchController.text.toLowerCase())
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
                  'Gestisci Squadre',
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
                hintText: 'Cerca squadre...',
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
            
            // Teams list
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
                                onPressed: _loadTeams,
                                child: const Text('Riprova'),
                              ),
                            ],
                          ),
                        )
                      : filteredTeams.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Nessuna squadra trovata'),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _createTeam,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Crea Squadra'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredTeams.length,
                              itemBuilder: (context, index) {
                                final team = filteredTeams[index];
                                final isSelected = _selectedTeamIds.contains(team.id);
                                
                                return ListTile(
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedTeamIds.add(team.id);
                                        } else {
                                          _selectedTeamIds.remove(team.id);
                                        }
                                      });
                                    },
                                  ),
                                  title: Text(team.name),
                                  subtitle: team.description != null
                                      ? Text(team.description!)
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _editTeam(team),
                                        tooltip: 'Modifica',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                        onPressed: () => _deleteTeam(team),
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
                  onPressed: _createTeam,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuova'),
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

