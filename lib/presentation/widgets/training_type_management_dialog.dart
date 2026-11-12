import 'package:flutter/material.dart';
import '../../../domain/entities/training_type.dart';
import '../../../data/datasources/remote/training_type_remote_datasource.dart';
import '../../../core/network/api_client.dart';

/// Dialog per gestire training types associati a un video
class TrainingTypeManagementDialog extends StatefulWidget {
  final String videoId;
  final List<String> currentTrainingTypeIds;
  
  const TrainingTypeManagementDialog({
    super.key,
    required this.videoId,
    required this.currentTrainingTypeIds,
  });
  
  @override
  State<TrainingTypeManagementDialog> createState() => _TrainingTypeManagementDialogState();
}

class _TrainingTypeManagementDialogState extends State<TrainingTypeManagementDialog> {
  late TrainingTypeRemoteDataSource _dataSource;
  List<TrainingType> _allTrainingTypes = [];
  List<String> _selectedTrainingTypeIds = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _dataSource = TrainingTypeRemoteDataSource(ApiClient());
    _selectedTrainingTypeIds = List.from(widget.currentTrainingTypeIds);
    _loadTrainingTypes();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTrainingTypes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final trainingTypes = await _dataSource.getTrainingTypes();
      setState(() {
        _allTrainingTypes = trainingTypes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _editTrainingType(TrainingType trainingType) async {
    final nameController = TextEditingController(text: trainingType.name);
    final descriptionController = TextEditingController(text: trainingType.description ?? '');
    final categoryController = TextEditingController(text: trainingType.category ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica Tipo Allenamento'),
        content: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoria (es: Riscaldamento, Esercizio, Partita)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
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
        final updatedTrainingType = await _dataSource.updateTrainingType(
          id: trainingType.id,
          name: nameController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
          category: categoryController.text.trim().isEmpty
              ? null
              : categoryController.text.trim(),
        );
        
        setState(() {
          final index = _allTrainingTypes.indexWhere((tt) => tt.id == trainingType.id);
          if (index != -1) {
            _allTrainingTypes[index] = updatedTrainingType;
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo allenamento aggiornato'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore aggiornamento tipo allenamento: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    nameController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
  }
  
  Future<void> _deleteTrainingType(TrainingType trainingType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Tipo Allenamento'),
        content: Text(
          'Sei sicuro di voler eliminare "${trainingType.name}"?\n\n'
          'Questa azione non può essere annullata. Il tipo allenamento verrà rimosso da tutti i video associati.',
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
        await _dataSource.deleteTrainingType(trainingType.id);
        
        setState(() {
          _allTrainingTypes.removeWhere((tt) => tt.id == trainingType.id);
          _selectedTrainingTypeIds.remove(trainingType.id);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo allenamento eliminato'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore eliminazione tipo allenamento: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  Future<void> _createTrainingType() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuovo Tipo Allenamento'),
        content: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 16),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoria (es: Riscaldamento, Esercizio, Partita)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
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
        final newTrainingType = await _dataSource.createTrainingType(
          name: nameController.text.trim(),
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
          category: categoryController.text.trim().isEmpty
              ? null
              : categoryController.text.trim(),
        );
        
        setState(() {
          _allTrainingTypes.add(newTrainingType);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tipo allenamento creato'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore creazione tipo allenamento: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    nameController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
  }
  
  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Rimuovi training types non più selezionati
      for (final trainingTypeId in widget.currentTrainingTypeIds) {
        if (!_selectedTrainingTypeIds.contains(trainingTypeId)) {
          try {
            await _dataSource.removeTrainingTypeFromVideo(widget.videoId, trainingTypeId);
          } catch (e) {
            // Ignora 404 - il training type potrebbe essere già stato rimosso o eliminato
            if (!e.toString().contains('404') && !e.toString().contains('not found')) {
              rethrow;
            }
          }
        }
      }
      
      // Aggiungi nuovi training types selezionati
      for (final trainingTypeId in _selectedTrainingTypeIds) {
        if (!widget.currentTrainingTypeIds.contains(trainingTypeId)) {
          // Verifica che il training type esista ancora nella lista
          if (_allTrainingTypes.any((tt) => tt.id == trainingTypeId)) {
            await _dataSource.addTrainingTypeToVideo(widget.videoId, trainingTypeId);
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
    final filteredTrainingTypes = _searchController.text.isEmpty
        ? _allTrainingTypes
        : _allTrainingTypes.where((tt) =>
            tt.name.toLowerCase().contains(_searchController.text.toLowerCase())
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
                  'Gestisci Tipo Allenamento',
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
                hintText: 'Cerca tipo allenamento...',
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
            
            // Training types list
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
                                onPressed: _loadTrainingTypes,
                                child: const Text('Riprova'),
                              ),
                            ],
                          ),
                        )
                      : filteredTrainingTypes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Nessun tipo allenamento trovato'),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _createTrainingType,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Crea Tipo Allenamento'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredTrainingTypes.length,
                              itemBuilder: (context, index) {
                                final trainingType = filteredTrainingTypes[index];
                                final isSelected = _selectedTrainingTypeIds.contains(trainingType.id);
                                
                                return ListTile(
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedTrainingTypeIds.add(trainingType.id);
                                        } else {
                                          _selectedTrainingTypeIds.remove(trainingType.id);
                                        }
                                      });
                                    },
                                  ),
                                  title: Text(trainingType.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (trainingType.category != null)
                                        Text('Categoria: ${trainingType.category}'),
                                      if (trainingType.description != null)
                                        Text(trainingType.description!),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _editTrainingType(trainingType),
                                        tooltip: 'Modifica',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                        onPressed: () => _deleteTrainingType(trainingType),
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
                  onPressed: _createTrainingType,
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

