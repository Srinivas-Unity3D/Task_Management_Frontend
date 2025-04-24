import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../models/view_state.dart';

class NavigationMenu extends StatelessWidget {
  final VoidCallback onMyTasksPressed;
  final VoidCallback onHistoryPressed;
  final VoidCallback onAssignTasksPressed;
  final VoidCallback onDashboardPressed;
  final ViewState currentView;

  const NavigationMenu({
    Key? key,
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
        const SizedBox(height: 24),
        _buildMenuItem(
          icon: Icons.dashboard,
          label: 'Dashboard',
          onTap: onDashboardPressed,
          isSelected: currentView == ViewState.dashboard,
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.task,
          label: 'My Tasks',
          onTap: onMyTasksPressed,
          isSelected: currentView == ViewState.myTasks,
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.history,
          label: 'History',
          onTap: onHistoryPressed,
          isSelected: currentView == ViewState.history,
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.assignment_ind_outlined,
          label: 'Assign Tasks',
          onTap: onAssignTasksPressed,
          isSelected: currentView == ViewState.assignTasks,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentCyan.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: AppColors.accentCyan, width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accentCyan : AppColors.textGrey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accentCyan : AppColors.textGrey,
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}