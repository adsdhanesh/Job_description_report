import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/task_manager.dart';

class NewTaskScreen extends StatefulWidget {
  const NewTaskScreen({super.key});

  @override
  State<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends State<NewTaskScreen> {
  final TextEditingController idCtl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TaskManager>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("New Task")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: idCtl,
              decoration: const InputDecoration(
                labelText: "Task ID",
                hintText: "Enter a task name / job ID",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final id = idCtl.text.trim();
                if (id.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Enter a valid task id")),
                  );
                  return;
                }

                manager.startTask(id);

                Navigator.pop(context);
              },
              child: const Text("Start Task"),
            ),
          ],
        ),
      ),
    );
  }
}
