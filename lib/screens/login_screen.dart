import 'package:flutter/material.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/constants.dart';
import '../core/theme_service.dart';
import '../services/auth_service.dart';
import '../models/auth_models.dart';
import 'admin_dashboard.dart';
import 'employee_dashboard.dart';
import 'workforce_dashboard.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

enum AuthMethod { password, otp }
enum OtpStep { email, verify }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();
  
  bool _loading = false;
  bool _showPassword = false;
  bool _isValidEmail = false;
  bool _rememberMe = true;
  
  AuthMethod _authMethod = AuthMethod.password;
  OtpStep _otpStep = OtpStep.email;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  String _appVersion = "1.0.0";

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVersion();
    _emailController.addListener(_validateEmail);
    // Focus listeners only update UI state (border colors), scrolling is handled by didChangeMetrics
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
    _otpFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.removeListener(_validateEmail);
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _otpFocusNode.dispose();
    _cooldownTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Check keyboard visibility and trigger scroll if needed
    // Using platformDispatcher directly avoids context issues in didChangeMetrics,
    // but verifying with context geometry in addPostFrameCallback is safer for layout logic.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      if (bottomInset > 100) { // Keyboard is open
         if (_emailFocusNode.hasFocus || _passwordFocusNode.hasFocus || _otpFocusNode.hasFocus) {
           _collapseHeader();
         }
      }
    });
  }

  void _collapseHeader() {
    // Minimal delay to let the frame stabilize after metrics change
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_scrollController.hasClients) return;
      
      final size = MediaQuery.of(context).size;
      final double expandedHeight = size.height * 0.4;
      final double collapsedHeight = 140.0; 
      
      final double targetOffset = expandedHeight - collapsedHeight;

      // Only animate if we aren't already there (or close enough)
      if ((_scrollController.offset - targetOffset).abs() > 5.0) {
          _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutQuart, // smoother premium feel
          );
      }
    });
  }

  // ... (existing methods: _initVersion, _startCooldown, _validateEmail, _isFormValid, _handleNavigation, _handleAuth, _signInWithPassword, _requestOtp, _signInWithOtp, _showError)

  Future<void> _initVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  void _validateEmail() {
    final email = _emailController.text;
    final emailRegex = RegExp(r"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$");
    setState(() {
      _isValidEmail = emailRegex.hasMatch(email);
    });
  }

  bool get _isFormValid {
    if (_authMethod == AuthMethod.password) {
      return _isValidEmail && _passwordController.text.length >= 6;
    } else {
      if (_otpStep == OtpStep.email) return _isValidEmail;
      return _otpController.text.length == 6;
    }
  }

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
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;
    Navigator.pushReplacement(
      context, 
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      )
    );
  }

  Future<void> _handleAuth() async {
    if (!_isFormValid) return;
    HapticFeedback.mediumImpact();
    
    if (_authMethod == AuthMethod.password) {
      await _signInWithPassword();
    } else {
      if (_otpStep == OtpStep.email) {
        await _requestOtp();
      } else {
        await _signInWithOtp();
      }
    }
  }

  Future<void> _signInWithPassword() async {
    setState(() => _loading = true);
    FocusScope.of(context).unfocus();

    try {
      final response = await AuthService().signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      final appUser = await AuthService().fetchUserProfile(response.user!.id);
      if (appUser == null) {
        _showError("Profile not found.");
        return;
      }
      TextInput.finishAutofillContext();
      await _handleNavigation(appUser);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestOtp() async {
    setState(() => _loading = true);
    try {
      await AuthService().sendOtp(_emailController.text.trim());
      _startCooldown();
      setState(() => _otpStep = OtpStep.verify);
    } catch (e) {
      _showError("Failed to send OTP: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithOtp() async {
    setState(() => _loading = true);
    try {
      final response = await AuthService().verifyOtp(
        _emailController.text.trim(),
        _otpController.text.trim(),
      );
      final appUser = await AuthService().fetchUserProfile(response.user!.id);
      if (appUser == null) {
        _showError("Profile not found.");
        return;
      }
      await _handleNavigation(appUser);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    StatusService.show(context, message, backgroundColor: Colors.red[600]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC);
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final size = MediaQuery.of(context).size;
    final double expandedHeight = size.height * 0.4;

    return Scaffold(
      backgroundColor: AppColors.primaryBlue, // Blue background for the "sheet" corner effect
      resizeToAvoidBottomInset: true,
      body: AbsorbPointer( // block interactions when loading
        absorbing: _loading,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: expandedHeight,
                  collapsedHeight: 140, 
                  pinned: true,
                  backgroundColor: AppColors.primaryBlue,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final top = constraints.biggest.height;
                      final padding = MediaQuery.of(context).padding.top;
                      final collapsedHeight = 140.0 + padding; 
                      
                      double fadePercent = (top - collapsedHeight) / (expandedHeight - collapsedHeight);
                      fadePercent = fadePercent.clamp(0.0, 1.0);
                      double textOpacity = (fadePercent - 0.3) / 0.7; 
                      textOpacity = textOpacity.clamp(0.0, 1.0);

                      return Container(
                        color: AppColors.primaryBlue, 
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SafeArea(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform.scale(
                                    scale: 1.0 - (0.1 * (1 - fadePercent)), 
                                    child: Container(
                                      width: 72, height: 72, padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white, borderRadius: BorderRadius.circular(20),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
                                      ), 
                                      child: Hero(tag: 'app_logo', child: Image.asset('assets/images/logomain.png', fit: BoxFit.contain)),
                                    ),
                                  ),
                                  
                                  if (textOpacity > 0) ...[
                                    const SizedBox(height: 16),
                                    Opacity(
                                      opacity: textOpacity,
                                      child: Column(
                                        children: [
                                          const Text(AppConstants.appName, style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                                          const SizedBox(height: 4),
                                          Text("ENTERPRISE CLOUD SYNC", style: TextStyle(fontFamily: 'Outfit', color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                                        ],
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                      boxShadow: [
                         BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 40), // Standard padding
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          if (_authMethod == AuthMethod.password) 
                            _buildPasswordFields(textPrimary, textSecondary)
                          else 
                            _buildOtpFields(textPrimary, textSecondary),
                          
                          const SizedBox(height: 40),
                          _buildFooter(textSecondary),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Removed overlay loader here
          ],
        ),
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.transparent)),
    );
  }

  Widget _buildPasswordFields(Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel("EMAIL ADDRESS"),
        const SizedBox(height: 10),
        TextFormField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          textInputAction: TextInputAction.next,
          style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textPrimary, fontWeight: FontWeight.w600),
          decoration: _inputDecoration("name@company.com", Icons.alternate_email_rounded, textSecondary, _emailFocusNode),
        ),
        const SizedBox(height: 24),
        _buildInputLabel("PASSWORD"),
        const SizedBox(height: 10),
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: !_showPassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleAuth(),
          style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textPrimary, fontWeight: FontWeight.w600),
          decoration: _inputDecoration("••••••••", Icons.lock_outline_rounded, textSecondary, _passwordFocusNode,
            isPassword: true,
            onToggleSuffix: () => setState(() => _showPassword = !_showPassword),
            showPassword: _showPassword
          ),
        ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? true),
                      activeColor: AppColors.primaryBlue),
                ),
                const SizedBox(width: 8),
                Text("Remember",
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimary)),
              ]),
              TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (c) => ForgotPasswordScreen(
                            initialEmail: _emailController.text))),
                child: const Text("Forgot Password?",
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildActionButton("SIGN IN", _handleAuth),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _authMethod = AuthMethod.otp;
                _otpStep = OtpStep.email;
              }),
              child: const Text("Sign in using OTP",
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const RegisterScreen())),
              child: RichText(
                text: TextSpan(
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        color: textSecondary,
                        fontSize: 14),
                    children: const [
                      TextSpan(text: "Don't have an account? "),
                      TextSpan(
                          text: "Register",
                          style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold)),
                    ]),
              ),
            ),
          ),
        ],
      );
  }

  Widget _buildOtpFields(Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_otpStep == OtpStep.email) ...[
          _buildInputLabel("EMAIL ADDRESS"),
          const SizedBox(height: 10),
          TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textPrimary, fontWeight: FontWeight.w600),
            decoration: _inputDecoration("name@company.com", Icons.alternate_email_rounded, textSecondary, _emailFocusNode),
          ),
          const SizedBox(height: 32),
          _buildActionButton("SEND OTP", _handleAuth),
        ] else ...[
          Center(
            child: Column(
              children: [
                const Icon(Icons.mark_email_unread_rounded, size: 48, color: AppColors.primaryBlue),
                const SizedBox(height: 16),
                const Text("Verify your Email", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Sent to ${_emailController.text}", style: TextStyle(fontFamily: 'Outfit', color: textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildInputLabel("6-DIGIT CODE"),
          const SizedBox(height: 10),
          TextField(
            controller: _otpController,
            focusNode: _otpFocusNode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: _inputDecoration("000000", null, textSecondary, _otpFocusNode).copyWith(
               counterText: "",
            ),
          ),
          const SizedBox(height: 32),
          _buildActionButton("VERIFY & SIGN IN", _handleAuth),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _resendCooldown > 0 ? null : _requestOtp,
              child: Text(
                _resendCooldown > 0 ? "Resend in ${_resendCooldown}s" : "Resend Code",
                style: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _authMethod = AuthMethod.password),
            child: const Text("Use Password instead", style: TextStyle(fontFamily: 'Outfit', color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
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
        gradient: LinearGradient(colors: _isFormValid ? [const Color(0xFF2563EB), const Color(0xFF1E3A8A)] : [Colors.grey.shade400, Colors.grey.shade500]),
        boxShadow: _isFormValid ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))] : [],
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

  Widget _buildFooter(Color textColor) {
    return Column(
      children: [
        Text("POWERED BY", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.w900, color: textColor.withOpacity(0.3), letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primaryBlue),
            const SizedBox(width: 4),
            Text("EZBILLIFY CLOUD", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w900, color: textColor.withOpacity(0.8), letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 16),
        Container(height: 4, width: 60, decoration: BoxDecoration(color: textColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 12),
        Text(
          "v$_appVersion", 
          style: TextStyle(
            fontFamily: 'Outfit', 
            fontSize: 10, 
            fontWeight: FontWeight.bold, 
            color: textColor.withOpacity(0.3),
          )
        ),
      ],
    );
  }
}
