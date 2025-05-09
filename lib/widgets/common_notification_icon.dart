import 'package:flutter/material.dart';
import '../screens/notifications_screen.dart';

class CommonNotificationIcon extends StatefulWidget {
  final bool hasUnreadNotifications;
  final VoidCallback? onNotificationCleared;

  const CommonNotificationIcon({
    Key? key,
    required this.hasUnreadNotifications,
    this.onNotificationCleared,
  }) : super(key: key);

  @override
  State<CommonNotificationIcon> createState() => _CommonNotificationIconState();
}

class _CommonNotificationIconState extends State<CommonNotificationIcon> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Repeat the animation
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        print('🔔 [NotificationIcon] Bell icon clicked');
        widget.onNotificationCleared?.call();
        print('🔔 [NotificationIcon] Navigating to NotificationScreen');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotificationScreen(),
          ),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(
                Icons.notifications_outlined,
                color: Color(0xFF7DF9FF),
                size: 24,
              ),
            ),
            if (widget.hasUnreadNotifications)
              Positioned(
                top: 8,
                right: 8,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red,
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 