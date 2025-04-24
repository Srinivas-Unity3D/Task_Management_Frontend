import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        _buildMenuItem(
          icon: Icons.assignment_outlined,
          label: 'My Tasks',
          onTap: () {
            // TODO: Navigate to My Tasks
          },
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.history,
          label: 'History',
          onTap: () {
            // TODO: Navigate to History
          },
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.assignment_ind_outlined,
          label: 'Assign Tasks',
          onTap: () {
            // TODO: Navigate to Assign Tasks
          },
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