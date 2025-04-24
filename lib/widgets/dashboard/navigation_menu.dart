import 'package:flutter/material.dart';

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMenuItem(
          icon: Icons.task,
          label: 'My Tasks',
          topMargin: 44,
        ),
        _buildMenuItem(
          icon: Icons.history,
          label: 'History',
          topMargin: 40,
        ),
        _buildMenuItem(
          icon: Icons.assignment,
          label: 'Assign Tasks',
          topMargin: 40,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required double topMargin,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topMargin, left: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF798598),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF798598),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}