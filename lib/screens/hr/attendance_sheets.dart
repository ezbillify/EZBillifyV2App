import 'package:flutter/material.dart';
import '../../models/attendance_model.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';
import 'package:intl/intl.dart';

class AttendanceAdjustSheet extends StatefulWidget {
  final AttendanceRecord record;
  final VoidCallback onSuccess;

  const AttendanceAdjustSheet({super.key, required this.record, required this.onSuccess});

  @override
  State<AttendanceAdjustSheet> createState() => _AttendanceAdjustSheetState();
}

class _AttendanceAdjustSheetState extends State<AttendanceAdjustSheet> {
  final _hrService = HrService();
  bool _loading = false;
  late TextEditingController _checkInController;
  late TextEditingController _checkOutController;
  String _status = 'present';

  @override
  void initState() {
    super.initState();
    _checkInController = TextEditingController(
      text: widget.record.checkIn != null ? DateFormat('HH:mm').format(widget.record.checkIn!) : "09:00"
    );
    _checkOutController = TextEditingController(
      text: widget.record.checkOut != null ? DateFormat('HH:mm').format(widget.record.checkOut!) : "18:00"
    );
    _status = widget.record.status;
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
    final picked = await showTimePicker(
      context: context, 
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), 
        child: child!
      ),
    );
    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() => controller.text = "$h:$m");
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      // Reconstruct DateTime from date string + time string
      final datePart = widget.record.date; // YYYY-MM-DD
      final ci = DateTime.parse("${datePart}T${_checkInController.text}:00");
      final co = DateTime.parse("${datePart}T${_checkOutController.text}:00");

      await _hrService.updateAttendanceRecord(widget.record.id!, {
        'check_in': ci.toIso8601String(),
        'check_out': co.toIso8601String(),
        'status': _status,
      });

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Adjust Time", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(_checkInController),
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _checkInController,
                      decoration: InputDecoration(labelText: "Check In", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(_checkOutController),
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _checkOutController,
                      decoration: InputDecoration(labelText: "Check Out", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _status,
            items: ['present', 'late', 'absent'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
            onChanged: (v) => setState(() => _status = v!),
            decoration: InputDecoration(labelText: "Status", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, 
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

class AttendanceDeviationSheet extends StatefulWidget {
  final AttendanceRecord record;
  final VoidCallback onSuccess;

  const AttendanceDeviationSheet({super.key, required this.record, required this.onSuccess});

  @override
  State<AttendanceDeviationSheet> createState() => _AttendanceDeviationSheetState();
}

class _AttendanceDeviationSheetState extends State<AttendanceDeviationSheet> {
  final _hrService = HrService();
  bool _loading = false;
  late TextEditingController _reasonController;
  String _status = 'late';

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(text: widget.record.deviationReason ?? '');
    _status = widget.record.status; 
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await _hrService.updateAttendanceRecord(widget.record.id!, {
        'deviation_reason': _reasonController.text.trim(),
        'status': _status,
      });

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
        left: 20, 
        right: 20, 
        top: 20
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Log Deviation", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Reason for Deviation",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _status,
            items: ['present', 'late', 'absent'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
            onChanged: (v) => setState(() => _status = v!),
            decoration: InputDecoration(labelText: "Status Impact", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, 
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("LOG DEVIATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
