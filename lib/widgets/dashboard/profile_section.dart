import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/colors.dart';
import '../../models/view_state.dart';
import 'navigation_menu.dart';

class ProfileSection extends StatelessWidget {
  final User user;
  final VoidCallback onProfileTap;
  final VoidCallback onMyTasksPressed;
  final VoidCallback onHistoryPressed;
  final VoidCallback onAssignTasksPressed;
  final VoidCallback onDashboardPressed;
  final ViewState currentView;

  const ProfileSection({
    Key? key,
    required this.user,
    required this.onProfileTap,
    required this.onMyTasksPressed,
    required this.onHistoryPressed,
    required this.onAssignTasksPressed,
    required this.onDashboardPressed,
    required this.currentView,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 80, 30),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000F2D),
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    color: AppColors.textGrey,
                    child: Center(
                      child: Text(
                        user.username[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      user.role,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          NavigationMenu(
            onMyTasksPressed: onMyTasksPressed,
            onHistoryPressed: onHistoryPressed,
            onAssignTasksPressed: onAssignTasksPressed,
            onDashboardPressed: onDashboardPressed,
            currentView: currentView,
          ),
        ],
      ),
    );
  }
}