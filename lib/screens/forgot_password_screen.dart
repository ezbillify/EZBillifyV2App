import 'package:flutter/material.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme_service.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _step = "email"; // email, otp, new_password, success
  bool _loading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  void _showError(String message) {
    StatusService.show(context, message, backgroundColor: AppColors.error);
  }

  Future<void> _requestOTP() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'com.ezbillify.app://reset-password',
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _step = "otp";
        });
      }
    } catch (e) {
      if (mounted) {
        _showError("Failed to send reset request: $e");
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _otpController.text.trim(),
        type: OtpType.recovery,
      );
      if (response.session != null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _step = "new_password";
          });
        }
      } else {
        if (mounted) {
          _showError("Verification failed.");
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError("Invalid or expired code.");
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_passwordController.text.length < 6) {
      _showError("Password must be at least 6 characters");
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Passwords do not match");
      return;
    }
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _step = "success";
        });
      }
    } catch (e) {
      if (mounted) {
        _showError("Failed to reset password: $e");
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeServiceProvider);
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final scaffoldBg = context.scaffoldBg;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_step != "success") ...[
              Text(
                _step == "email" ? "Forgot Password?" : 
                _step == "otp" ? "Verify Code" : "New Password",
                style: TextStyle(fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                _step == "email" ? "Enter your email and we'll send a 6-digit code." :
                _step == "otp" ? "We've sent a code to ${_emailController.text}" :
                "Create a strong password to secure your account.",
                style: TextStyle(fontFamily: 'Outfit', color: textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 40),
            ],

            if (_step == "email") _buildEmailStep(),
            if (_step == "otp") _buildOtpStep(),
            if (_step == "new_password") _buildPasswordStep(),
            if (_step == "success") _buildSuccessStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      children: [
        _buildTextField(
          controller: _emailController,
          label: "Email Address",
          hint: "name@company.com",
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: "Send Reset Code",
          onPressed: _requestOTP,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      children: [
        _buildTextField(
          controller: _otpController,
          label: "6-Digit Code",
          hint: "000000",
          icon: Icons.shield_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: "Verify Code",
          onPressed: _verifyOTP,
        ),
        TextButton(
          onPressed: _requestOTP,
          child: const Text("Didn't receive it? Resend", style: TextStyle(fontFamily: 'Outfit', color: AppColors.primaryBlue)),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      children: [
        _buildTextField(
          controller: _passwordController,
          label: "New Password",
          hint: "••••••••",
          icon: Icons.lock_outline,
          obscureText: !_showPassword,
          suffix: IconButton(
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: context.textSecondary),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _confirmPasswordController,
          label: "Confirm Password",
          hint: "••••••••",
          icon: Icons.check_circle_outline,
          obscureText: !_showPassword,
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(
          label: "Reset Password",
          onPressed: _resetPassword,
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.check_circle, size: 100, color: AppColors.success),
          const SizedBox(height: 32),
          Text("Success!", style: TextStyle(fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.bold, color: context.textPrimary)),
          const SizedBox(height: 12),
          Text("Your password has been reset successfully.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary, fontSize: 16)),
          const SizedBox(height: 48),
          _buildPrimaryButton(
            label: "Back to Login",
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final inputFill = context.inputFill;
    final borderColor = context.borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputFill,
            hintText: hint,
            hintStyle: TextStyle(fontFamily: 'Outfit', color: textSecondary.withOpacity(0.5)),
            prefixIcon: Icon(icon, color: textSecondary, size: 22),
            suffixIcon: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback onPressed}) {
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
          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
