import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Widget calendario per filtrare video per data
/// Permette selezione di giorni singoli o range
class VideoDateCalendar extends StatefulWidget {
  final DateTime? selectedDateFrom;
  final DateTime? selectedDateTo;
  final Function(DateTime?, DateTime?) onDateRangeSelected;
  final VoidCallback onClear;

  const VideoDateCalendar({
    super.key,
    required this.selectedDateFrom,
    required this.selectedDateTo,
    required this.onDateRangeSelected,
    required this.onClear,
  });

  @override
  State<VideoDateCalendar> createState() => _VideoDateCalendarState();
}

class _VideoDateCalendarState extends State<VideoDateCalendar> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isLocaleInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = widget.selectedDateFrom;
    _rangeStart = widget.selectedDateFrom;
    _rangeEnd = widget.selectedDateTo;
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

  @override
  void didUpdateWidget(VideoDateCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDateFrom != oldWidget.selectedDateFrom ||
        widget.selectedDateTo != oldWidget.selectedDateTo) {
      _selectedDay = widget.selectedDateFrom;
      _rangeStart = widget.selectedDateFrom;
      _rangeEnd = widget.selectedDateTo;
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _selectedDay = selectedDay;
      
      // Se non c'è un range o se clicchiamo su un giorno diverso, inizia un nuovo range
      if (_rangeStart == null || _rangeEnd != null) {
        // Inizia nuovo range (singolo giorno)
        _rangeStart = selectedDay;
        _rangeEnd = selectedDay;
      } else {
        // Completa il range
        if (selectedDay.isBefore(_rangeStart!)) {
          // Se il giorno selezionato è prima del range start, scambia
          _rangeEnd = _rangeStart;
          _rangeStart = selectedDay;
        } else {
          _rangeEnd = selectedDay;
        }
      }
      
      // Applica immediatamente il filtro
      // Se from e to sono lo stesso giorno, è un singolo giorno
      widget.onDateRangeSelected(_rangeStart, _rangeEnd);
    });
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
      _selectedDay = null;
    });
    
    // Applica immediatamente il filtro
    widget.onDateRangeSelected(start, end);
  }

  bool _isSelected(DateTime day) {
    if (_selectedDay != null && isSameDay(_selectedDay, day)) return true;
    if (_rangeStart != null && isSameDay(_rangeStart, day)) return true;
    if (_rangeEnd != null && isSameDay(_rangeEnd, day)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _rangeStart != null || _selectedDay != null;
    
    if (!_isLocaleInitialized) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.all(12),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con titolo e pulsante clear
          Row(
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_today, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Filtra per Data',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (hasSelection)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDay = null;
                      _rangeStart = null;
                      _rangeEnd = null;
                    });
                    widget.onClear();
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Rimuovi'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Info selezione
          if (hasSelection)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _rangeEnd != null
                          ? 'Periodo: ${_formatDate(_rangeStart!)} - ${_formatDate(_rangeEnd!)}'
                          : 'Giorno: ${_formatDate(_rangeStart ?? _selectedDay!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Calendario - limitato in altezza per evitare overflow
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 320, // Altezza massima per evitare overflow
            ),
            child: TableCalendar(
              firstDay: DateTime(2000),
              lastDay: DateTime.now(),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: _isSelected,
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              onDaySelected: _onDaySelected,
              onRangeSelected: _onRangeSelected,
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              rangeSelectionMode: RangeSelectionMode.enforced,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.red[300]),
                selectedDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.blue[200],
                  shape: BoxShape.circle,
                ),
                rangeStartDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                rangeEndDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                withinRangeDecoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(0),
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'it_IT',
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

