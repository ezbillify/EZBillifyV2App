import 'package:flutter/material.dart';

class StatusService {
  static OverlayEntry? _activeStatusOverlay;

  static void show(BuildContext context, String message, {bool isLoading = false, Color? backgroundColor, bool persistent = false}) {
    if (_activeStatusOverlay != null) {
      try { _activeStatusOverlay?.remove(); } catch (_) {}
      _activeStatusOverlay = null;
    }

    final overlay = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Default color logic
    final defaultBg = backgroundColor ?? (isDark ? const Color(0xFF1E293B) : Colors.black.withOpacity(0.9));

    _activeStatusOverlay = OverlayEntry(
      builder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: defaultBg,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: defaultBg.withOpacity(0.3), 
                            blurRadius: 20, 
                            offset: const Offset(0, 10)
                          )
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoading) ...[
                            const SizedBox(
                              width: 14, 
                              height: 14, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                            ),
                            const SizedBox(width: 12),
                          ] else if (backgroundColor == Colors.green || (backgroundColor == null && message.toLowerCase().contains('success'))) ...[
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                          ] else if (backgroundColor == Colors.red || (backgroundColor == null && (message.toLowerCase().contains('error') || message.toLowerCase().contains('fail')))) ...[
                            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                          ] else if (backgroundColor == Colors.orange) ...[
                             const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                             const SizedBox(width: 12),
                          ],
                          Flexible(
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 13, 
                                fontFamily: 'Outfit'
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_activeStatusOverlay!);

    if (!persistent) {
      Future.delayed(const Duration(seconds: 3), () {
        if (_activeStatusOverlay != null) {
          try { _activeStatusOverlay?.remove(); } catch (_) {}
          _activeStatusOverlay = null;
        }
      });
    }
  }

  static void hide() {
    if (_activeStatusOverlay != null) {
      try { _activeStatusOverlay?.remove(); } catch (_) {}
      _activeStatusOverlay = null;
    }
  }
}
