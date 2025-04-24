import 'package:flutter/material.dart';
import '../widgets/dashboard/profile_section.dart';
import '../widgets/dashboard/navigation_menu.dart';
import '../widgets/dashboard/stats_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  Widget _buildNotificationIcon({bool hasUnreadNotifications = true}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Bell Icon centered in container
          const Center(
            child: Icon(
              Icons.notifications_outlined,
              color: Color(0xFF7DF9FF),
              size: 24,
            ),
          ),
          // Red dot for unread notifications
          if (hasUnreadNotifications)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          color: Colors.white,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 50),
              color: const Color(0xFF0A0F1C),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProfileSection(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Dashboard',
                        style: TextStyle(
                          color: Color(0xFF7DF9FF),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                      _buildNotificationIcon(hasUnreadNotifications: true),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const StatsCard(
                    title: 'Active Tasks',
                    count: '2',
                  ),
                  const SizedBox(height: 24),
                  const StatsCard(
                    title: 'Completed',
                    count: '1',
                  ),
                  const SizedBox(height: 24),
                  const StatsCard(
                    title: 'Snoozed',
                    count: '0',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}