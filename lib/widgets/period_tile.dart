import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../utils/time_utils.dart';

class PeriodTile extends StatelessWidget {
  final PeriodLog period;

  const PeriodTile({super.key, required this.period});

  @override
  Widget build(BuildContext context) {
    final dur = period.duration;
    return ListTile(
      leading: Icon(
        period.status.toLowerCase() == 'idle'
            ? Icons.pause_circle
            : Icons.schedule,
      ),
      title: Text(period.description),
      subtitle: Text(
          '${shortTime(period.from)} - ${shortTime(period.to)} (${formatDuration(dur)})'),
      trailing: Text(period.status),
    );
  }
}
