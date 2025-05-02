import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String count;
  final VoidCallback? onTap;

  const StatsCard({
    Key? key,
    required this.title,
    required this.count,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.borderColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 36,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}