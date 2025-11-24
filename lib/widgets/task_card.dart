import 'package:flutter/material.dart';
import '../models/task_model.dart';
import 'period_tile.dart';
import '../utils/time_utils.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onClose;
  final VoidCallback? onAddHourDesc;

  const TaskCard({
    super.key,
    required this.task,
    this.onClose,
    this.onAddHourDesc,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate active time (exclude idle/inactive)
    final activeDuration = task.periodLogs.fold<Duration>(
      Duration.zero,
      (prev, p) =>
          prev +
          (p.status.toLowerCase() == 'idle' ||
                  p.status.toLowerCase() == 'inactive'
              ? Duration.zero
              : p.duration),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ExpansionTile(
        title: Text(
          '${task.taskId}  •  ${shortTime(task.startTime)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Active: ${formatDuration(activeDuration)}  •  Status: ${task.status}',
        ),
        children: [
          // ALL PERIOD LOGS
          ...task.periodLogs.map((p) => PeriodTile(period: p)).toList(),

          const SizedBox(height: 10),

          // ACTION BUTTONS
          ButtonBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onAddHourDesc,
                child: const Text('Add Hour Description'),
              ),
              TextButton(
                onPressed: onClose,
                child: const Text('Close Task'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
