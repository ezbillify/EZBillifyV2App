import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/theme_service.dart';
import '../services/auth_service.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _firstNameFocusNode = FocusNode();
  final _lastNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _showError(String message) {
    StatusService.show(context, message, backgroundColor: AppColors.error);
  }

  void _showSuccess(String message) {
    StatusService.show(context, message, backgroundColor: AppColors.success);
  }

  bool _validateForm() {
    if (_firstNameController.text.trim().isEmpty) {
      _showError("First name is required");
      return false;
    }
    if (_emailController.text.trim().isEmpty) {
      _showError("Email is required");
      return false;
    }
    if (!RegExp(r"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$").hasMatch(_emailController.text.trim())) {
      _showError("Please enter a valid email address");
      return false;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showError("Phone number is required");
      return false;
    }
    if (_phoneController.text.trim().length < 10) {
      _showError("Enter valid 10-digit mobile number");
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _showError("Password is required");
      return false;
    }
    if (_passwordController.text.length < 6) {
      _showError("Must be at least 6 characters");
      return false;
    }
    if (_confirmPasswordController.text != _passwordController.text) {
      _showError("Passwords do not match");
      return false;
    }
    return true;
  }

  Future<void> _handleRegister() async {
    if (!_validateForm()) return;
    
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();

    try {
      final response = await AuthService().signUp(
        _emailController.text.trim(),
        _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (response.session == null) {
        _showSuccess("Registration successful! Please check your email for verification.");
        TextInput.finishAutofillContext();
        Navigator.pop(context);
      } else {
        // Redirection handled by auth state listener in main or splash
        _showSuccess("Welcome to EZBillify!");
        TextInput.finishAutofillContext();
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primaryBlue,
            elevation: 0,
            automaticallyImplyLeading: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text("Create Account", 
                style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)
              ),
              background: Container(
                color: AppColors.primaryBlue,
                child: Center(
                  child: Opacity(
                    opacity: 0.2,
                    child: Icon(Icons.person_add_rounded, size: 100, color: Colors.white.withOpacity(0.5)),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
              ),
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("JOIN US", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryBlue, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Text("Start your journey with EZBillify", style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 4),
                        Text("Streamline your business operations", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  _buildRegisterFields(textPrimary, textSecondary),
                  
                  const SizedBox(height: 40),
                  _buildActionButton("CREATE ACCOUNT", _handleRegister),
                  
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontFamily: 'Outfit', color: textSecondary, fontSize: 14),
                          children: const [
                            TextSpan(text: "Already have an account? "),
                            TextSpan(text: "Sign In", style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                          ]
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterFields(Color textPrimary, Color textSecondary) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel("FIRST NAME"),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _firstNameController,
                      focusNode: _firstNameFocusNode,
                      autofillHints: const [AutofillHints.givenName],
                      textInputAction: TextInputAction.next,
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textPrimary, fontWeight: FontWeight.w600),
                      decoration: _inputDecoration("John", Icons.person_outline_rounded, textSecondary, _firstNameFocusNode),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel("LAST NAME"),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _lastNameController,
                      focusNode: _lastNameFocusNode,
                      autofillHints: const [AutofillHints.familyName],
                      textInputAction: TextInputAction.next,
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textPrimary, fontWeight: FontWeight.w600),
                      decoration: _inputDecoration("Doe", Icons.person_outline_rounded, textSecondary, _lastNameFocusNode),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInputLabel("EMAIL ADDRESS"),
          const SizedBox(height: 10),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            textInputAction: TextInputAction.next,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textPrimary, fontWeight: FontWeight.w600),
            decoration: _inputDecoration("john@company.com", Icons.alternate_email_rounded, textSecondary, _emailFocusNode),
          ),
          const SizedBox(height: 24),
           _buildInputLabel("MOBILE NUMBER"),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phoneController,
            focusNode: _phoneFocusNode,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.next,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textPrimary, fontWeight: FontWeight.w600),
            decoration: _inputDecoration("9876543210", Icons.phone_android_rounded, textSecondary, _phoneFocusNode),
          ),
          const SizedBox(height: 24),
          _buildInputLabel("PASSWORD"),
          const SizedBox(height: 10),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: !_showPassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textPrimary, fontWeight: FontWeight.w600),
            decoration: _inputDecoration("••••••••", Icons.lock_outline_rounded, textSecondary, _passwordFocusNode,
              isPassword: true,
              onToggleSuffix: () => setState(() => _showPassword = !_showPassword),
              showPassword: _showPassword
            ),
          ),
          const SizedBox(height: 24),
          _buildInputLabel("CONFIRM PASSWORD"),
          const SizedBox(height: 10),
          TextFormField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocusNode,
            obscureText: !_showConfirmPassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleRegister(),
            style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textPrimary, fontWeight: FontWeight.w600),
            decoration: _inputDecoration("••••••••", Icons.lock_reset_rounded, textSecondary, _confirmPasswordFocusNode,
              isPassword: true,
              onToggleSuffix: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
              showPassword: _showConfirmPassword
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryBlue, letterSpacing: 1.2));
  }

  InputDecoration _inputDecoration(String hint, IconData? icon, Color color, FocusNode focusNode, {bool isPassword = false, VoidCallback? onToggleSuffix, bool showPassword = false}) {
    final isDark = context.isDark;
    return InputDecoration(
      filled: true,
      fillColor: focusNode.hasFocus ? AppColors.primaryBlue.withOpacity(isDark ? 0.1 : 0.05) : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      hintText: hint, 
      hintStyle: TextStyle(fontFamily: 'Outfit', color: color.withOpacity(0.4), fontWeight: FontWeight.normal),
      prefixIcon: icon != null ? Icon(icon, color: focusNode.hasFocus ? AppColors.primaryBlue : color.withOpacity(0.5), size: 20) : null,
      suffixIcon: isPassword ? IconButton(icon: Icon(showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: color.withOpacity(0.5)), onPressed: onToggleSuffix) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
       enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity, height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [const Color(0xFF2563EB), const Color(0xFF1E3A8A)]),
        boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading ? null : onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(label, style: const TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }
}
