import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/training_type.dart';
import '../../domain/entities/team.dart';
import '../../data/datasources/remote/player_remote_datasource.dart';
import '../../data/datasources/remote/training_type_remote_datasource.dart';
import '../../data/datasources/remote/team_remote_datasource.dart';
import '../../core/network/api_client.dart';
import '../../features/video/viewmodels/video_list_viewmodel.dart';

/// Widget per filtri video (giocatori, esercizi, squadre, date)
class VideoFiltersSection extends StatefulWidget {
  const VideoFiltersSection({super.key});

  @override
  State<VideoFiltersSection> createState() => _VideoFiltersSectionState();
}

class _VideoFiltersSectionState extends State<VideoFiltersSection> {
  final PlayerRemoteDataSource _playerDataSource = PlayerRemoteDataSource(ApiClient());
  final TrainingTypeRemoteDataSource _trainingTypeDataSource = TrainingTypeRemoteDataSource(ApiClient());
  final TeamRemoteDataSource _teamDataSource = TeamRemoteDataSource(ApiClient());
  
  List<Player> _allPlayers = [];
  List<TrainingType> _allTrainingTypes = [];
  List<Team> _allTeams = [];
  bool _isLoading = false;
  
  List<String> _selectedPlayerIds = [];
  List<String> _selectedTrainingTypeIds = [];
  List<String> _selectedTeamIds = [];
  DateTime? _recordedDateFrom;
  DateTime? _recordedDateTo;
  
  @override
  void initState() {
    super.initState();
    _loadFilters();
    // Carica filtri attivi dal ViewModel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWithViewModel();
    });
  }
  
  void _syncWithViewModel() {
    final viewModel = context.read<VideoListViewModel>();
    setState(() {
      _selectedPlayerIds = viewModel.playerIds ?? [];
      _selectedTrainingTypeIds = viewModel.trainingTypeIds ?? [];
      _selectedTeamIds = viewModel.teamIds ?? [];
      _recordedDateFrom = viewModel.recordedDateFrom;
      _recordedDateTo = viewModel.recordedDateTo;
    });
  }
  
  Future<void> _loadFilters() async {
    setState(() => _isLoading = true);
    try {
      final players = await _playerDataSource.getPlayers();
      final trainingTypes = await _trainingTypeDataSource.getTrainingTypes();
      final teams = await _teamDataSource.getTeams();
      
      if (mounted) {
        setState(() {
          _allPlayers = players;
          _allTrainingTypes = trainingTypes;
          _allTeams = teams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _applyFilters() {
    final viewModel = context.read<VideoListViewModel>();
    viewModel.setFilters(
      playerIds: _selectedPlayerIds.isEmpty ? null : _selectedPlayerIds,
      trainingTypeIds: _selectedTrainingTypeIds.isEmpty ? null : _selectedTrainingTypeIds,
      teamIds: _selectedTeamIds.isEmpty ? null : _selectedTeamIds,
      recordedDateFrom: _recordedDateFrom,
      recordedDateTo: _recordedDateTo,
    );
  }
  
  void _clearFilters() {
    setState(() {
      _selectedPlayerIds = [];
      _selectedTrainingTypeIds = [];
      _selectedTeamIds = [];
      _recordedDateFrom = null;
      _recordedDateTo = null;
    });
    final viewModel = context.read<VideoListViewModel>();
    viewModel.clearFilters();
  }
  
  bool get _hasActiveFilters {
    return _selectedPlayerIds.isNotEmpty ||
           _selectedTrainingTypeIds.isNotEmpty ||
           _selectedTeamIds.isNotEmpty ||
           _recordedDateFrom != null ||
           _recordedDateTo != null;
  }

  Future<void> _showCalendarFilter() async {
    // Sincronizza prima per essere sicuri di avere lo stato aggiornato
    _syncWithViewModel();
    
    // Prendi il ViewModel una volta sola PRIMA di aprire il dialogo
    final viewModel = context.read<VideoListViewModel>();
    
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CalendarFilterSheet(
          initialFrom: _recordedDateFrom,
          initialTo: _recordedDateTo,
          viewModel: viewModel,
          isBottomSheet: true,
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
            child: CalendarFilterSheet(
              initialFrom: _recordedDateFrom,
              initialTo: _recordedDateTo,
              viewModel: viewModel,
              isBottomSheet: false,
            ),
          ),
        ),
      );
    }
    
    // Dopo la chiusura del dialogo, sincronizza lo stato locale
    if (mounted) {
      _syncWithViewModel();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con pulsante clear
          Row(
            children: [
              const Text(
                'Filtri',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton(
                  onPressed: _clearFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Rimuovi filtri', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Filtri orizzontali scrollabili
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Giocatori',
                  icon: Icons.person,
                  count: _selectedPlayerIds.length,
                  onTap: () => _showPlayerFilterDialog(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Esercizi',
                  icon: Icons.fitness_center,
                  count: _selectedTrainingTypeIds.length,
                  onTap: () => _showTrainingTypeFilterDialog(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Squadre',
                  icon: Icons.group,
                  count: _selectedTeamIds.length,
                  onTap: () => _showTeamFilterDialog(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Data Registrazione',
                  icon: Icons.calendar_today,
                  count: _recordedDateFrom != null || _recordedDateTo != null ? 1 : 0,
                  onTap: () => _showCalendarFilter(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required int count,
    required VoidCallback onTap,
  }) {
    final isActive = count > 0;
    final isAndroid = Platform.isAndroid;
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          if (!isAndroid) ...[
            const SizedBox(width: 4),
            Text(label),
          ],
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue,
      tooltip: isAndroid ? label : null, // Mostra tooltip su Android quando si passa sopra
    );
  }
  
  Future<void> _showPlayerFilterDialog() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _FilterSelectionDialog<Player>(
        title: 'Filtra per Giocatori',
        items: _allPlayers,
        selectedIds: _selectedPlayerIds,
        itemBuilder: (player) => player.name,
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedPlayerIds = result;
      });
      _applyFilters();
    }
  }
  
  Future<void> _showTrainingTypeFilterDialog() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _FilterSelectionDialog<TrainingType>(
        title: 'Filtra per Esercizi',
        items: _allTrainingTypes,
        selectedIds: _selectedTrainingTypeIds,
        itemBuilder: (tt) => tt.name,
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedTrainingTypeIds = result;
      });
      _applyFilters();
    }
  }
  
  Future<void> _showTeamFilterDialog() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _FilterSelectionDialog<Team>(
        title: 'Filtra per Squadre',
        items: _allTeams,
        selectedIds: _selectedTeamIds,
        itemBuilder: (team) => team.name,
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedTeamIds = result;
      });
      _applyFilters();
    }
  }
  
}

/// Dialog per selezione multipla di filtri
class _FilterSelectionDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final List<String> selectedIds;
  final String Function(T) itemBuilder;
  final String Function(T)? getId;
  
  const _FilterSelectionDialog({
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.itemBuilder,
    this.getId,
  });
  
  @override
  State<_FilterSelectionDialog<T>> createState() => _FilterSelectionDialogState<T>();
}

class _FilterSelectionDialogState<T> extends State<_FilterSelectionDialog<T>> {
  late List<String> _selectedIds;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.selectedIds);
  }
  
  String _getId(T item) {
    if (widget.getId != null) {
      return widget.getId!(item);
    }
    return (item as dynamic).id.toString();
  }
  
  List<T> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return widget.items;
    }
    return widget.items.where((item) {
      final name = widget.itemBuilder(item).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Cerca...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final id = _getId(item);
                  final isSelected = _selectedIds.contains(id);
                  
                  return CheckboxListTile(
                    title: Text(widget.itemBuilder(item)),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(id);
                        } else {
                          _selectedIds.remove(id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedIds),
                  child: const Text('Applica'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget calendario per il filtro date - Pulito e autonomo
class CalendarFilterSheet extends StatefulWidget {
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final VideoListViewModel viewModel;
  final bool isBottomSheet;

  const CalendarFilterSheet({
    super.key,
    this.initialFrom,
    this.initialTo,
    required this.viewModel,
    this.isBottomSheet = false,
  });

  @override
  State<CalendarFilterSheet> createState() => _CalendarFilterSheetState();
}

class _CalendarFilterSheetState extends State<CalendarFilterSheet> {
  late DateTime _focusedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _isLocaleInitialized = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialFrom ?? DateTime.now();
    _rangeStart = widget.initialFrom;
    _rangeEnd = widget.initialTo;
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('it_IT', null);
    if (mounted) {
      setState(() {
        _isLocaleInitialized = true;
      });
    }
  }

  // Callback per selezione range - usato da TableCalendar
  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
    });
    
    // Applica solo quando abbiamo almeno una data
    if (start != null) {
      _applyChanges();
    }
  }

  // Callback per selezione singolo giorno (fallback)
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _rangeStart = selectedDay;
      _rangeEnd = selectedDay;
    });
    _applyChanges();
  }

  void _applyChanges() {
    DateTime? normalizedFrom;
    DateTime? normalizedTo;

    if (_rangeStart != null) {
      normalizedFrom = DateTime.utc(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day, 12, 0, 0);
    }
    
    // Se end è null ma start c'è, usa start come end (singolo giorno)
    final effectiveEnd = _rangeEnd ?? _rangeStart;
    if (effectiveEnd != null) {
      normalizedTo = DateTime.utc(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day, 12, 0, 0);
    }
    
    // Aggiorna direttamente il ViewModel (che è un oggetto stabile, non dipende dal widget tree)
    widget.viewModel.setFilters(
      playerIds: widget.viewModel.playerIds,
      trainingTypeIds: widget.viewModel.trainingTypeIds,
      teamIds: widget.viewModel.teamIds,
      recordedDateFrom: normalizedFrom,
      recordedDateTo: normalizedTo,
    );
  }

  void _clearSelection() {
    setState(() {
      _rangeStart = null;
      _rangeEnd = null;
      _focusedDay = DateTime.now();
    });
    
    // Aggiorna direttamente il ViewModel
    widget.viewModel.setFilters(
      playerIds: widget.viewModel.playerIds,
      trainingTypeIds: widget.viewModel.trainingTypeIds,
      teamIds: widget.viewModel.teamIds,
      recordedDateFrom: null,
      recordedDateTo: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _rangeStart != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : const BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar per mobile
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header e pulsanti
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Filtra per Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (hasSelection)
                  TextButton(
                    onPressed: _clearSelection,
                    child: const Text('Rimuovi'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          if (!_isLocaleInitialized)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            // Calendario
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TableCalendar(
                  firstDay: DateTime(2000),
                  lastDay: DateTime.now(),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Mese',
                  },
                  
                  // Selezione: usiamo range con onRangeSelected
                  rangeSelectionMode: RangeSelectionMode.toggledOn,
                  rangeStartDay: _rangeStart,
                  rangeEndDay: _rangeEnd,
                  
                  onRangeSelected: _onRangeSelected,
                  onDaySelected: _onDaySelected,
                  
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  locale: 'it_IT',
                  
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    weekendTextStyle: TextStyle(
                      color: Colors.red[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    todayTextStyle: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.blue[100],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue[600]!,
                        width: 2,
                      ),
                    ),
                    rangeStartDecoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    rangeEndDecoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    withinRangeDecoration: BoxDecoration(
                      color: Colors.blue[50],
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(0),
                    ),
                    withinRangeTextStyle: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: Colors.blue[600],
                      size: 28,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: Colors.blue[600],
                      size: 28,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    weekendStyle: TextStyle(
                      color: Colors.red[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
