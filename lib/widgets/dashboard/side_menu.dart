import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/colors.dart';

class SideMenu extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;
  final VoidCallback onClose;

  const SideMenu({
    Key? key,
    required this.user,
    required this.onLogout,
    required this.onClose,
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
      onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: double.infinity,
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            color: AppColors.cardBackground,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: AppColors.textGrey,
                          child: Text(
                            user.username[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
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
                              user.role,
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildMenuItem(
            icon: Icons.assignment_outlined,
            label: 'My Tasks',
            onTap: () {
              // TODO: Navigate to My Tasks
              onClose();
            },
          ),
          _buildMenuItem(
            icon: Icons.history,
            label: 'History',
            onTap: () {
              // TODO: Navigate to History
              onClose();
            },
          ),
          _buildMenuItem(
            icon: Icons.assignment_ind_outlined,
            label: 'Assign Tasks',
            onTap: () {
              // TODO: Navigate to Assign Tasks
              onClose();
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
            onTap: () {
              // TODO: Handle exit
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppColors.textGrey,
        size: 24,
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }
} 