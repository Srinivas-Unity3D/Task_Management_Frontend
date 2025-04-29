import 'package:flutter/material.dart';
import '../services/socket_service.dart';

class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({Key? key}) : super(key: key);

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final _socketService = SocketService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Your scaffold implementation here
    );
  }
} 