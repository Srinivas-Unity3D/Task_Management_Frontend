import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class NavigationMenu extends StatelessWidget {
  final VoidCallback onMyTasksPressed;
  final VoidCallback onHistoryPressed;
  final VoidCallback onAssignTasksPressed;
  final VoidCallback onDashboardPressed;

  const NavigationMenu({
    Key? key,
    required this.onMyTasksPressed,
    required this.onHistoryPressed,
    required this.onAssignTasksPressed,
    required this.onDashboardPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.dashboard,
          label: 'Dashboard',
          onTap: onDashboardPressed,
        ),
        _buildMenuItem(
          icon: Icons.task,
          label: 'My Tasks',
          onTap: onMyTasksPressed,
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.history,
          label: 'History',
          onTap: onHistoryPressed,
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.assignment_ind_outlined,
          label: 'Assign Tasks',
          onTap: onAssignTasksPressed,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.textGrey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}