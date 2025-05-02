import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for SystemNavigator
import '../../theme/colors.dart';
import '../../models/user.dart';

class SidePanel extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onClose;
  final User user;
  final String currentRoute;

  const SidePanel({
    Key? key,
    required this.onLogout,
    required this.onClose,
    required this.user,
    required this.currentRoute,
  }) : super(key: key);

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Logout',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'No',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 14,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Yes',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      Navigator.of(context).pop(); // Close the side panel
      onLogout();
    }
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text(
            'Exit App',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            'Are you sure you want to close the app?',
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'No',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 14,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Yes',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      // Close the app
      SystemNavigator.pop();
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? route,
  }) {
    final bool isSelected = route != null && route == currentRoute;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.inputBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Icon(
          icon,
          color: isSelected ? AppColors.accentCyan : AppColors.textGrey,
          size: 24,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.accentCyan : AppColors.white,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75,
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.inputBackground,
                          child: Text(
                            user.username[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.accentCyan,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.username,
                              style: const TextStyle(
                                color: AppColors.accentCyan,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              user.role == 'admin' ? 'Software Developer' : user.role,
                              style: const TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.textGrey,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Menu Items
              _buildMenuItem(
                icon: Icons.home_outlined,
                label: 'Dashboard',
                route: '/',
                onTap: () {
                  Navigator.pop(context);
                  if (currentRoute != '/') {
                    Navigator.pushReplacementNamed(context, '/');
                  }
                },
              ),
              _buildMenuItem(
                icon: Icons.task_outlined,
                label: 'My Tasks',
                route: '/my-tasks',
                onTap: () {
                  Navigator.pop(context);
                  if (currentRoute != '/my-tasks') {
                    Navigator.pushNamed(context, '/my-tasks');
                  }
                },
              ),
              _buildMenuItem(
                icon: Icons.assignment_ind_outlined,
                label: 'Assign Tasks',
                route: '/assign-tasks',
                onTap: () {
                  Navigator.pop(context);
                  if (currentRoute != '/assign-tasks') {
                    Navigator.pushNamed(context, '/assign-tasks');
                  }
                },
              ),
              const Spacer(),
              _buildMenuItem(
                icon: Icons.logout,
                label: 'Logout',
                onTap: () => _showLogoutConfirmation(context),
              ),
              _buildMenuItem(
                icon: Icons.exit_to_app,
                label: 'Exit',
                onTap: () => _showExitConfirmation(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
} 