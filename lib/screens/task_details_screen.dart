import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/task_manager.dart';
import '../models/task_model.dart';
import '../utils/time_utils.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailsScreen({super.key, required this.taskId});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  Task? taskRef;

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TaskManager>(context);

    taskRef = manager.tasks.where((t) => t.taskId == widget.taskId).isNotEmpty
        ? manager.tasks.firstWhere((t) => t.taskId == widget.taskId)
        : null;

    if (taskRef == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task details')),
        body: const Center(child: Text('Task not found')),
      );
    }

    final task = taskRef!;
    final activeTotal = manager.totalActiveDurationForTask(task);

    return Scaffold(
      appBar: AppBar(title: Text('Task ${task.taskId}')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Started: ${task.startTime.toLocal()}'),
            const SizedBox(height: 8),
            Text('Status: ${task.status}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Active total: ${formatDuration(activeTotal)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Periods:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: task.periodLogs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final p = task.periodLogs[i];

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        p.status.toLowerCase() == 'idle'
                            ? Icons.pause_circle
                            : Icons.access_time,
                      ),
                      title: Text(p.description ?? "No Description"),
                      subtitle: Text(
                        '${shortTime(p.from)} - ${shortTime(p.to)} (${formatDuration(p.duration)})',
                      ),
                      trailing: Text(p.status ?? "Unknown"),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  child: const Text('Add Hour Description'),
                  onPressed: () async {
                    final ctl = TextEditingController();
                    final desc = await showDialog<String?>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Description'),
                        content: TextField(
                          controller: ctl,
                          decoration: const InputDecoration(
                              hintText: 'What did you do?'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, ctl.text),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );

                    if (desc != null && desc.trim().isNotEmpty) {
                      manager.closePeriod(task, description: desc);
                      manager.startNewActivePeriod(task, description: desc);
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  child: const Text('Close Task'),
                  onPressed: task.status == 'Inactive'
                      ? null
                      : () async {
                          await manager.endTask(task);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${task.taskId} closed')),
                          );
                          setState(() {});
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
