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
        width: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'SORT BY PRIORITY',
                style: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _buildFilterOption('Urgent Tasks', () => onPrioritySelected('high')),
            _buildFilterOption('Medium Priority', () => onPrioritySelected('medium')),
            _buildFilterOption('Low Priority', () => onPrioritySelected('low')),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'SORT BY ASSIGNEE',
                style: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _buildFilterOption('Assignee (A-Z)', () => onAssigneeSort('asc')),
            _buildFilterOption('Assignee (Z-A)', () => onAssigneeSort('desc')),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'OTHER',
                style: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _buildFilterOption('Recent Tasks', onRecentTasksSelected),
            _buildFilterOption('Role', () => onRoleSelected('role')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
} 