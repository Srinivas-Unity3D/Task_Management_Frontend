import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../models/task.dart';
import '../services/api_service.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({Key? key}) : super(key: key);

  @override
  _MyTasksScreenState createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final ApiService _apiService = ApiService();
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      setState(() => _isLoading = true);
      final response = await _apiService.getTasks(username: '', role: ''); // TODO: Get from shared prefs
      if (response['success']) {
        final tasksJson = response['data'] as List;
        setState(() {
          _tasks = tasksJson.map((task) => Task.fromJson(task)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading tasks: ${e.toString()}'),
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
          'My Tasks',
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
          : _tasks.isEmpty
              ? const Center(
                  child: Text(
                    'No tasks available',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
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
                        title: Text(
                          task.title,
                          style: const TextStyle(
                            color: AppColors.accentCyan,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: AppColors.textGrey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Due ${_formatDate(task.deadline)}',
                                  style: const TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 12,
                                  ),
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