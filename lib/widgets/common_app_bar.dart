import 'package:flutter/material.dart';
import '../theme/colors.dart';
import './common_notification_icon.dart';

class CommonAppBar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final bool hasUnreadNotifications;
  final VoidCallback onNotificationCleared;

  const CommonAppBar({
    Key? key,
    required this.onMenuPressed,
    required this.hasUnreadNotifications,
    required this.onNotificationCleared,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onMenuPressed,
              icon: const Icon(
                Icons.menu,
                color: AppColors.accentCyan,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            CommonNotificationIcon(
              hasUnreadNotifications: hasUnreadNotifications,
              onNotificationCleared: onNotificationCleared,
            ),
          ],
        ),
      ),
    );
  }
} 