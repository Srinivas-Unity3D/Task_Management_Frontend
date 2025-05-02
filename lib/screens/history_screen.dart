import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../models/task.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<Task> _completedTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletedTasks();
  }

  Future<void> _loadCompletedTasks() async {
    try {
      setState(() => _isLoading = true);
      final response = await _apiService.getCompletedTasks();
      if (response['success']) {
        final tasksJson = response['data'] as List;
        setState(() {
          _completedTasks = tasksJson.map((task) => Task.fromJson(task)).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: ${response['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading history: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        title: const Text(
          'History',
          style: TextStyle(
            color: AppColors.accentCyan,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.accentCyan),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentCyan),
            )
          : _completedTasks.isEmpty
              ? const Center(
                  child: Text(
                    'No completed tasks',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _completedTasks.length,
                  itemBuilder: (context, index) {
                    final task = _completedTasks[index];
                    return Card(
                      color: AppColors.cardBackground,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppColors.borderColor.withOpacity(0.1),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.accentCyan,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(
                                  color: AppColors.accentCyan,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              task.description,
                              style: TextStyle(
                                color: AppColors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: AppColors.textGrey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Completed ${_formatDate(task.completedAt ?? DateTime.now())}',
                                      style: const TextStyle(
                                        color: AppColors.textGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppColors.inputBackground,
                                      child: Text(
                                        task.assignedBy[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.accentCyan,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      task.assignedBy,
                                      style: const TextStyle(
                                        color: AppColors.textGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
  }
} 