import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/task_model.dart';
import 'json_storage.dart';

class TaskManager extends ChangeNotifier {
  final List<Task> tasks = [];

  TaskManager();

  void addTask(Task t) {
    tasks.add(t);
    notifyListeners();
  }

  Task startTask(String id, {String description = 'Started'}) {
    final now = DateTime.now();
    final t = Task(
      taskId: id,
      startTime: now,
      status: 'Active',
      periodLogs: [
        PeriodLog(
            from: now, to: now, description: description, status: 'Active')
      ],
    );
    tasks.add(t);
    notifyListeners();
    return t;
  }

  Future<void> endTask(Task t) async {
    final now = DateTime.now();
    try {
      if (t.periodLogs.isNotEmpty) {
        final last = t.periodLogs.last;
        if (last.to.isAtSameMomentAs(last.from) || last.to.isBefore(now)) {
          last.to = now;
        }
      }
    } catch (_) {}

    t.endTime = now;
    t.status = 'Inactive';
    notifyListeners();
  }

  void startNewActivePeriod(Task t, {String description = 'Resumed'}) {
    final now = DateTime.now();
    if (t.status == 'Inactive') {
      t.status = 'Active';
      t.endTime = null;
    }
    t.periodLogs.add(PeriodLog(
        from: now, to: now, description: description, status: 'Active'));
    t.status = 'Active';
    notifyListeners();
  }

  void closePeriod(Task t, {String description = ''}) {
    final now = DateTime.now();
    if (t.periodLogs.isEmpty) return;

    final last = t.periodLogs.last;
    // Only close if last is open (to == from) or last.to is in the future
    if (last.to.isAtSameMomentAs(last.from) || last.to.isAfter(last.from)) {
      last.to = now;
    }
    if (description.isNotEmpty) last.description = description;
    notifyListeners();
  }

  void markIdle(Task t, DateTime lastUserActivity) {
    final now = DateTime.now();
    try {
      if (t.periodLogs.isNotEmpty) {
        final last = t.periodLogs.last;
        if (last.status.toLowerCase() == 'active') {
          last.to = lastUserActivity.isAfter(last.from)
              ? lastUserActivity
              : last.from;
        }
      }

      t.periodLogs.add(PeriodLog(
          from: lastUserActivity,
          to: now,
          description: 'Auto idle',
          status: 'Idle'));
      t.status = 'Idle';
      notifyListeners();
    } catch (_) {}
  }

  void recoverFromSleep(Task t, Duration gap) {
    final now = DateTime.now();
    if (gap <= Duration.zero) return;
    final from = now.subtract(gap);

    t.periodLogs.add(PeriodLog(
        from: from,
        to: now,
        description: 'Recovered from sleep',
        status: 'Idle'));
    t.status = 'Idle';
    notifyListeners();
  }

  void logHourlyWork(Task t, String description) {
    final now = DateTime.now();
    // Close last active period
    if (t.periodLogs.isNotEmpty) {
      final last = t.periodLogs.last;
      if (last.status.toLowerCase() == 'active') {
        last.to = now;
        if (description.isNotEmpty) last.description = description;
      }
    }

    t.periodLogs.add(PeriodLog(
        from: now,
        to: now,
        description: description.isNotEmpty ? description : 'Hourly log',
        status: 'Active'));
    t.status = 'Active';
    notifyListeners();
  }

  Duration totalActiveDurationForTask(Task t) {
    Duration total = Duration.zero;
    final now = DateTime.now();

    for (final p in t.periodLogs) {
      if (p == null) continue;
      final st = p.from;
      final en = (p.to.isAtSameMomentAs(p.from)) ? now : p.to;
      final status = p.status.toLowerCase();
      if (!status.contains('idle') && !status.contains('inactive')) {
        total += en.difference(st);
      }
    }
    if (t.periodLogs.isEmpty && t.status.toLowerCase() != 'inactive') {
      total += now.difference(t.startTime);
    }
    return total;
  }

  int countActiveTasks() {
    return tasks
        .where((t) =>
            t.status.toLowerCase() != 'inactive' &&
            t.status.toLowerCase() != 'idle')
        .length;
  }

  void deleteTasksByIds(List<String> ids) {
    tasks.removeWhere((t) => ids.contains(t.taskId));
    notifyListeners();
  }

  Future<void> clearAll() async {
    tasks.clear();
    await JsonStorage.clear();
    notifyListeners();
  }

  Future<String> exportJson() async {
    try {
      final data = tasks.map((t) => t.toJson()).toList();
      final map = {
        'exportedAt': DateTime.now().toIso8601String(),
        'taskCount': tasks.length,
        'tasks': data,
      };
      return jsonEncode(map);
    } catch (e) {
      return jsonEncode(
          {'error': 'Failed to export JSON', 'message': e.toString()});
    }
  }

  Future<void> importFromJsonString(String jsonStr) async {
    try {
      final decoded = json.decode(jsonStr);
      List<dynamic> items;
      if (decoded is Map && decoded['tasks'] is List) {
        items = decoded['tasks'] as List<dynamic>;
      } else if (decoded is List) {
        items = decoded;
      } else {
        return;
      }

      tasks.clear();
      for (final e in items) {
        if (e is Map<String, dynamic>) {
          tasks.add(Task.fromJson(e));
        } else if (e is Map) {
          tasks.add(Task.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> save() async {
    return;
  }

  Future<void> load() async {
    return;
  }
}
