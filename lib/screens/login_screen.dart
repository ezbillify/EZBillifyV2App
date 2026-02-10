import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/theme_service.dart';
import '../services/auth_service.dart';
import '../models/auth_models.dart';
import 'admin_dashboard.dart';
import 'employee_dashboard.dart';
import 'workforce_dashboard.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  
  bool _loading = false;
  bool _showPassword = false;
  bool _isValidEmail = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final email = _emailController.text;
    final emailRegex = RegExp(r"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$");
    setState(() {
      _isValidEmail = emailRegex.hasMatch(email);
    });
  }

  void _onPasswordChanged() {
    setState(() {}); // Refresh form validity
  }

  bool get _isFormValid => _isValidEmail && _passwordController.text.length >= 6;

  Future<void> _handleNavigation(AppUser appUser) async {
    Widget nextScreen;
    switch (appUser.role) {
      case UserRole.admin:
      case UserRole.owner:
        nextScreen = const AdminDashboard();
        break;
      case UserRole.employee:
        nextScreen = const EmployeeDashboard();
        break;
      case UserRole.workforce:
        nextScreen = const WorkforceDashboard();
        break;
      default:
        _showError("Unauthorized role detected (${appUser.role.name}).");
        return;
    }
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(builder: (context) => nextScreen)
    );
  }

  Future<void> _signIn() async {
    if (!_isFormValid) return;
    setState(() => _loading = true);
    FocusScope.of(context).unfocus();

    try {
      final response = await AuthService().signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      final appUser = await AuthService().fetchUserProfile(response.user!.id);
      if (!mounted) return;

      if (appUser == null) {
        _showError("Your profile or active roles were not found.");
        return;
      }

      await _handleNavigation(appUser);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError("An unexpected error occurred: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bgColor = isDark ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final inputFill = isDark ? AppColors.darkInputFill : Colors.grey.withOpacity(0.05);
    final borderColor = isDark ? AppColors.darkBorder : Colors.grey.withOpacity(0.1);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
                  child: Column(
                    children: [
                      _buildFields(textPrimary, textSecondary, inputFill, borderColor),
                      const SizedBox(height: 48),
                      _buildFooter(textSecondary),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.3,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, const Color(0xFF1D4ED8)], 
          begin: Alignment.topCenter, 
          end: Alignment.bottomCenter
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60, 
              height: 60, 
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), 
              child: Image.asset('assets/images/logomain.png', fit: BoxFit.contain)
            ),
            const SizedBox(height: 12),
            Text(AppConstants.appName, style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            Text("Secure Operator Portal", style: TextStyle(fontFamily: 'Outfit', color: Colors.white.withOpacity(0.8), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildFields(Color textPrimary, Color textSecondary, Color inputFill, Color borderColor) {
    return Column(
      children: [
        _buildFieldLabel("Email Address", textPrimary),
        const SizedBox(height: 10),
        _buildDecoratedField(
          inputFill: inputFill,
          borderColor: borderColor,
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: textPrimary),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: "name@company.com",
              hintStyle: TextStyle(fontFamily: 'Outfit', color: textSecondary),
              prefixIcon: Icon(Icons.email_outlined, color: textSecondary), 
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildFieldLabel("Password", textPrimary),
        const SizedBox(height: 10),
        _buildDecoratedField(
          inputFill: inputFill,
          borderColor: borderColor,
          child: TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: textPrimary),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: "••••••••",
              hintStyle: TextStyle(fontFamily: 'Outfit', color: textSecondary),
              prefixIcon: Icon(Icons.lock_outline, color: textSecondary), 
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: textSecondary), 
                onPressed: () => setState(() => _showPassword = !_showPassword)
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (c) => ForgotPasswordScreen(initialEmail: _emailController.text))
            ),
            child: Text("Forgot Password?", style: TextStyle(fontFamily: 'Outfit', color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 32),
        _buildActionButton("Sign In", _signIn),
      ],
    );
  }

  Widget _buildFieldLabel(String label, Color textColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Widget _buildDecoratedField({required Widget child, required Color inputFill, required Color borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _loading 
          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFooter(Color textColor) {
    return Column(
      children: [
        Text("POWERED BY", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.6), letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text("EZBILLIFY TECHNOLOGY", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w800, color: textColor.withOpacity(0.8), letterSpacing: 0.5)),
      ],
    );
  }
}
