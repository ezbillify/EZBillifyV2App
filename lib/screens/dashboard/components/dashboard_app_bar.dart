import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../core/theme_service.dart';

class DashboardAppBar extends ConsumerWidget {
  final VoidCallback onProfileTap;

  const DashboardAppBar({
    super.key,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final user = state.currentUser;
    final surfaceColor = context.surfaceBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          const double expandedHeight = 120.0;
          const double kToolbarHeight = 70.0;
          final double currentHeight = constraints.biggest.height;
          final double t = ((currentHeight - kToolbarHeight) / (expandedHeight - kToolbarHeight)).clamp(0.0, 1.0);

          return FlexibleSpaceBar(
            expandedTitleScale: 1.0,
            titlePadding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: lerpDouble(10, 15, t)!,
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logomain.png',
                            height: lerpDouble(22, 38, t),
                            width: lerpDouble(22, 38, t),
                            fit: BoxFit.contain,
                          ),
                          SizedBox(width: lerpDouble(8, 12, t)),
                          Text(
                            "EZBillify V2",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: lerpDouble(16, 22, t),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: lerpDouble(2, 6, t)!),
                        child: Text(
                          "Hello, ${user?.name?.split(' ').first ?? 'User'}",
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: lerpDouble(10, 16, t),
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(lerpDouble(0.1, 0.2, t)!),
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: lerpDouble(16, 24, t),
                      backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                      child: Text(
                        (user?.name ?? "U")[0].toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: lerpDouble(11, 16, t),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            background: Container(color: surfaceColor),
          );
        },
      ),
    );
  }
}
