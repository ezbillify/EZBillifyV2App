import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../core/theme_service.dart';

class UserManagementScreen extends ConsumerWidget {
  final String companyId;
  const UserManagementScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeServiceProvider);
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: UserManagementView(companyId: companyId, showBackButton: true),
    );
  }
}

class UserManagementView extends ConsumerStatefulWidget {
  final String companyId;
  final bool showBackButton;
  const UserManagementView({super.key, required this.companyId, this.showBackButton = false});

  @override
  ConsumerState<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends ConsumerState<UserManagementView> {
  final _settingsService = SettingsService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await _settingsService.getUsers(widget.companyId);
      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeUser(String userId, String name) async {
    final surfaceColor = context.surfaceBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Remove User", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary)),
        content: Text("Are you sure you want to remove $name? This action cannot be undone.", style: TextStyle(fontFamily: 'Outfit', color: textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(fontFamily: 'Outfit', color: textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Remove", style: TextStyle(fontFamily: 'Outfit', color: AppColors.error, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _settingsService.removeUser(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User removed successfully'),
            backgroundColor: AppColors.success,
          ));
        }
        _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeServiceProvider);
    
    final isDark = context.isDark;
    final surfaceColor = context.surfaceBg;
    final cardColor = context.cardBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final borderColor = context.borderColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildHeader(surfaceColor, textPrimary, textSecondary),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return _buildUserCard(user, cardColor, textPrimary, textSecondary, borderColor, isDark);
                    },
                  ),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInviteDialog(),
        backgroundColor: isDark ? AppColors.primaryBlue : AppColors.lightTextPrimary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(Color surfaceColor, Color textPrimary, Color textSecondary) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.showBackButton) ...[
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textPrimary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                "Staff Management",
                style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Manage your team and their permissions",
            style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: textSecondary),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog() {
    final isDark = context.isDark;
    final surfaceColor = context.surfaceBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final inputFill = context.inputFill;

    final emailController = TextEditingController();
    String selectedRole = 'workforce';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          ref.watch(themeServiceProvider);
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: context.surfaceBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      children: [
                        Text("Invite Member", style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
                        const SizedBox(height: 8),
                        Text("Add a new staff member to your business", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary)),
                        const SizedBox(height: 32),
                        _buildDialogField("Email Address", emailController, context.textPrimary, context.textSecondary, context.inputFill, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        Text("Assign Role", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
                        const SizedBox(height: 8),
                        StatefulBuilder(
                          builder: (context, setInternalState) => _buildDropdownField(
                            "Select Role", 
                            selectedRole, 
                            ['admin', 'workforce', 'employee'],
                            context.textPrimary,
                            context.textSecondary,
                            context.inputFill,
                            (v) => setInternalState(() => selectedRole = v!)
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (emailController.text.isEmpty) return;
                              try {
                                await _settingsService.inviteUser({
                                  'email': emailController.text,
                                  'role': selectedRole.toUpperCase(),
                                  'company_id': widget.companyId,
                                  'status': 'active',
                                });
                                if (mounted) Navigator.pop(context);
                                _loadUsers();
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.isDark ? AppColors.primaryBlue : AppColors.lightTextPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text("Send Invitation", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, Color textPrimary, Color textSecondary, Color inputFill, ValueChanged<String?> onSelected) {
    return InkWell(
      onTap: () => _showSelectionSheet(label, options, value, onSelected),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
            Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
          ],
        ),
      ),
    );
  }

  void _showSelectionSheet(String title, List<String> options, String currentValue, ValueChanged<String?> onSelected) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          ref.watch(themeServiceProvider);
          return DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.7,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: context.surfaceBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
                        const SizedBox(height: 8),
                        Text("Select a role for this user account", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        ...options.map((opt) {
                          final isSelected = opt == currentValue;
                          return ListTile(
                            onTap: () {
                              onSelected(opt);
                              Navigator.pop(context);
                            },
                            contentPadding: EdgeInsets.zero,
                            title: Text(opt.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppColors.primaryBlue : context.textPrimary)),
                            trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 24) : null,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, Color textPrimary, Color textSecondary, Color inputFill, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontFamily: 'Outfit', color: textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> userMap, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor, bool isDark) {
    final String name = userMap['name'] ?? 'Pending User';
    final String email = userMap['email'] ?? 'N/A';
    final String id = userMap['id']?.toString() ?? '';
    final roles = userMap['user_roles'] as List?;
    final String role = roles != null && roles.isNotEmpty ? roles[0]['role'].toString().toUpperCase() : 'EMPLOYEE';
    
    return InkWell(
      onTap: () => _showUserDetailSheet(userMap),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? context.scaffoldBg : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(name[0].toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary, fontSize: 18)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                  Text(email, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.w900, color: _getRoleColor(role), letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                if (role != 'OWNER')
                  InkWell(
                    onTap: () => _removeUser(id, name),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetailSheet(Map<String, dynamic> user) {
    final String name = user['name'] ?? 'Pending User';
    final String email = user['email'] ?? 'N/A';
    final String id = user['id']?.toString() ?? '';
    final roles = user['user_roles'] as List?;
    final String role = roles != null && roles.isNotEmpty ? roles[0]['role'].toString().toUpperCase() : 'EMPLOYEE';
    final branchName = roles != null && roles.isNotEmpty && roles[0]['branches'] != null ? roles[0]['branches']['name'] : 'All Branches';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          ref.watch(themeServiceProvider);
          final textPrimary = context.textPrimary;
          final textSecondary = context.textSecondary;
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: context.surfaceBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(32),
                      children: [
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: context.isDark ? context.scaffoldBg : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Center(
                              child: Text(name[0].toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(child: Text(name, style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary))),
                        Center(child: Text(email, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: textSecondary))),
                        const SizedBox(height: 32),
                        _buildDetailRow("Primary Role", role, textPrimary, textSecondary),
                        _buildDetailRow("Assigned Branch", branchName, textPrimary, textSecondary),
                        _buildDetailRow("Employee ID", id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase(), textPrimary, textSecondary),
                        _buildDetailRow("Status", "Active", textPrimary, textSecondary),
                        const SizedBox(height: 48),
                        if (role != 'OWNER') ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _removeUser(id, name);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text("Revoke Access", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: textSecondary)),
          Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'OWNER': return const Color(0xFF7C3AED);
      case 'ADMIN': return AppColors.primaryBlue;
      case 'WORKFORCE': return AppColors.success;
      default: return const Color(0xFF64748B);
    }
  }
}
