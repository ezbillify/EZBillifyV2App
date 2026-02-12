import 'package:flutter/material.dart';
import '../../models/shift_model.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import 'shift_form_sheet.dart';

class ShiftListScreen extends StatefulWidget {
  const ShiftListScreen({super.key});

  @override
  State<ShiftListScreen> createState() => _ShiftListScreenState();
}

class _ShiftListScreenState extends State<ShiftListScreen> {
  final _hrService = HrService();
  final _authService = AuthService();
  List<Shift> _shifts = [];
  bool _loading = true;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _loading = true);
    try {
      final user = await _authService.getCurrentUser();
      _companyId = user?.companyId;
      if (_companyId != null) {
        final list = await _hrService.getShifts(_companyId!);
        if (mounted) setState(() => _shifts = list);
      }
    } catch (_) {
      // Handle error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openShiftSheet([Shift? shift]) {
    if (_companyId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ShiftFormSheet(
          shift: shift,
          companyId: _companyId!,
          onSuccess: _loadShifts,
        ),
      ),
    );
  }

  Future<void> _deleteShift(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Shift"),
        content: const Text("Are you sure you want to delete this shift?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _hrService.deleteShift(id);
      _loadShifts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("Shifts & Roster", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadShifts),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openShiftSheet(),
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator())
          : _shifts.isEmpty 
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shifts.length,
                  itemBuilder: (c, i) => _buildShiftCard(_shifts[i], isDark),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No shifts found",
            style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Shift shift, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (shift.isActive ? Colors.green : Colors.grey).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.access_time_filled, color: shift.isActive ? Colors.green : Colors.grey),
        ),
        title: Text(
          shift.name,
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
        ),
        subtitle: Text(
          "${shift.startTime} - ${shift.endTime} • ${shift.breakDurationMinutes}m Break",
          style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white54 : Colors.grey[600]),
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, color: isDark ? Colors.white54 : Colors.grey[600]),
          onSelected: (v) {
            if (v == 'edit') _openShiftSheet(shift);
            if (v == 'delete') _deleteShift(shift.id!);
          },
          itemBuilder: (c) => [
            const PopupMenuItem(value: 'edit', child: Text("Edit")),
            const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}
