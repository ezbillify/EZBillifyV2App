import 'package:flutter/material.dart';
import '../../models/shift_model.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';

class ShiftFormScreen extends StatefulWidget {
  final Shift? shift;
  final String companyId;

  const ShiftFormScreen({super.key, this.shift, required this.companyId});

  @override
  State<ShiftFormScreen> createState() => _ShiftFormScreenState();
}

class _ShiftFormScreenState extends State<ShiftFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hrService = HrService();
  bool _loading = false;

  late TextEditingController _nameController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _breakController;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final s = widget.shift;
    _nameController = TextEditingController(text: s?.name ?? '');
    _startTimeController = TextEditingController(text: s?.startTime ?? "09:00");
    _endTimeController = TextEditingController(text: s?.endTime ?? "18:00");
    _breakController = TextEditingController(text: s?.breakDurationMinutes.toString() ?? "60");
    _isActive = s?.isActive ?? true;
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), // Force 24h
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      setState(() => controller.text = "$hour:$minute");
    }
  }

  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final shift = Shift(
        id: widget.shift?.id,
        name: _nameController.text.trim(),
        startTime: _startTimeController.text,
        endTime: _endTimeController.text,
        breakDurationMinutes: int.tryParse(_breakController.text) ?? 60,
        isActive: _isActive,
        companyId: widget.companyId,
      );

      if (widget.shift == null) {
        await _hrService.createShift(shift, widget.companyId);
      } else {
        await _hrService.updateShift(shift);
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(widget.shift == null ? "New Shift" : "Edit Shift", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _loading ? null : _saveShift)
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTextField(_nameController, "Shift Name (e.g., Morning Shift)", required: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectTime(_startTimeController),
                          child: AbsorbPointer(
                            child: _buildTextField(_startTimeController, "Start Time", icon: Icons.access_time),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectTime(_endTimeController),
                          child: AbsorbPointer(
                            child: _buildTextField(_endTimeController, "End Time", icon: Icons.access_time_filled),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_breakController, "Break Duration (minutes)", type: TextInputType.number),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text("Active Shift", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    value: _isActive,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (v) => setState(() => _isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _saveShift,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("SAVE SHIFT", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool required = false, TextInputType? type, IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87),
      validator: required ? (v) => v == null || v.isEmpty ? "Required" : null : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white60 : Colors.black54),
        suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
      ),
    );
  }
}
