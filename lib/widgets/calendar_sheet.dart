import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../core/theme_service.dart';

class CalendarSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  const CalendarSheet({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.title = "Select Date",
  });

  @override
  State<CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<CalendarSheet> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate;
    _selectedDay = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                widget.title,
                style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, _selectedDay),
                child: const Text("Done", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 10),
          TableCalendar(
            firstDay: widget.firstDate,
            lastDay: widget.lastDate,
            focusedDay: _focusedDay,
            currentDay: DateTime.now(),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focused) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focused;
              });
            },
            calendarStyle: CalendarStyle(
               defaultTextStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87),
               weekendTextStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white70 : Colors.black54),
               selectedDecoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
               todayDecoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.3), shape: BoxShape.circle),
               todayTextStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
            ),
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              leftChevronIcon: Icon(Icons.chevron_left, color: isDark ? Colors.white : Colors.black54),
              rightChevronIcon: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper method to show the sheet easily
Future<DateTime?> showCustomCalendarSheet({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = "Select Date",
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CalendarSheet(
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      title: title,
    ),
  );
}
