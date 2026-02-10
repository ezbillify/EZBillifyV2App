import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/theme_service.dart';
import '../services/auth_service.dart';
import '../models/auth_models.dart';
import 'login_screen.dart';
import 'admin_dashboard.dart';
import 'employee_dashboard.dart';
import 'workforce_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _logoOpacity;

  late AnimationController _textController;
  late List<Animation<double>> _letterOffsets;
  late List<Animation<double>> _letterOpacities;
  
  late AnimationController _taglineController;
  late Animation<double> _taglineOffset;
  late Animation<double> _taglineOpacity;

  final String _appName = AppConstants.appName;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _logoRotation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _letterOffsets = List.generate(_appName.length, (index) {
      final start = 0.2 + (index * 0.05);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 20, end: 0).animate(
        CurvedAnimation(
          parent: _textController,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });

    _letterOpacities = List.generate(_appName.length, (index) {
      final start = 0.2 + (index * 0.05);
      final end = (start + 0.2).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _textController,
          curve: Interval(start, end, curve: Curves.easeIn),
        ),
      );
    });

    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _taglineOffset = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _taglineController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _taglineController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    _logoController.forward();
    _textController.forward();
    _taglineController.forward();

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    try {
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session == null) {
        _navigate(const LoginScreen());
        return;
      }

      final appUser = await AuthService().fetchUserProfile(session.user.id).timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      if (appUser == null) {
        await AuthService().signOut();
        _navigate(const LoginScreen());
        return;
      }

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
          await AuthService().signOut();
          nextScreen = const LoginScreen();
      }

      _navigate(nextScreen);
    } catch (e) {
      debugPrint("Splash Error: $e");
      _navigate(const LoginScreen());
    }
  }

  void _navigate(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2563EB), 
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.5),
                    const Color(0xFF2563EB),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.rotate(
                        angle: _logoRotation.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logomain.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.account_balance_wallet_rounded, size: 80, color: Colors.white);
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_appName.length, (index) {
                    return AnimatedBuilder(
                      animation: _textController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _letterOpacities[index].value,
                          child: Transform.translate(
                            offset: Offset(0, _letterOffsets[index].value),
                            child: Text(
                              _appName[index],
                              style: const TextStyle(fontFamily: 'Outfit', 
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
                
                const SizedBox(height: 12),
                
                AnimatedBuilder(
                  animation: _taglineController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _taglineOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _taglineOffset.value),
                        child: Text(
                          AppConstants.appTagline,
                          style: TextStyle(fontFamily: 'Outfit', 
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
