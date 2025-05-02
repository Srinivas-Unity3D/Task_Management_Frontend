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
    return Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onProfileTap,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.inputBackground,
                    child: Text(
                      user.username[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        user.role,
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        NavigationMenu(
          onMyTasksPressed: onMyTasksPressed,
          onHistoryPressed: onHistoryPressed,
          onAssignTasksPressed: onAssignTasksPressed,
          onDashboardPressed: onDashboardPressed,
          currentView: currentView,
        ),
      ],
    );
  }
}