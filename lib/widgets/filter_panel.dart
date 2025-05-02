import 'package:flutter/material.dart';
import '../theme/colors.dart';

class FilterPanel extends StatelessWidget {
  final Function(String) onPrioritySelected;
  final Function(String) onAssigneeSort;
  final Function() onRecentTasksSelected;
  final Function(String) onRoleSelected;

  const FilterPanel({
    Key? key,
    required this.onPrioritySelected,
    required this.onAssigneeSort,
    required this.onRecentTasksSelected,
    required this.onRoleSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderColor.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SORT BY PRIORITY',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildFilterOption('Urgent Tasks', () => onPrioritySelected('high')),
            _buildFilterOption('Medium Priority', () => onPrioritySelected('medium')),
            _buildFilterOption('Low Priority', () => onPrioritySelected('low')),
            const SizedBox(height: 16),
            const Text(
              'SORT BY ASSIGNEE',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildFilterOption('Assignee (A-Z)', () => onAssigneeSort('asc')),
            _buildFilterOption('Assignee (Z-A)', () => onAssigneeSort('desc')),
            const SizedBox(height: 16),
            const Text(
              'OTHER',
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildFilterOption('Recent Tasks', onRecentTasksSelected),
            _buildFilterOption('Role', () => onRoleSelected('role')),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
} 