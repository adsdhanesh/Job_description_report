import 'dart:convert';

//
// PERIOD LOG MODEL
//
class PeriodLog {
  DateTime from;
  DateTime to;
  String description;
  String status; // Active, Idle, Inactive, Meeting

  PeriodLog({
    required this.from,
    required this.to,
    required this.description,
    required this.status,
  });

  Duration get duration => to.difference(from);

  Map<String, dynamic> toJson() => {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'description': description,
        'status': status,
      };

  factory PeriodLog.fromJson(Map<String, dynamic> j) => PeriodLog(
        from: DateTime.parse(j['from'] as String),
        to: DateTime.parse(j['to'] as String),
        status: (j['status'] ?? "Active") as String,
        description: (j['description'] ?? "No Description") as String,
      );
}

//
// TASK MODEL
//
class Task {
  String taskId;
  DateTime startTime;
  DateTime? endTime;
  String status; // Active / Idle / Inactive
  List<PeriodLog> periodLogs;

  Task({
    required this.taskId,
    required this.startTime,
    this.endTime,
    this.status = 'Active',
    List<PeriodLog>? periodLogs,
  }) : periodLogs = periodLogs ?? [];

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'status': status,
        'periodLogs': periodLogs.map((p) => p.toJson()).toList(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        taskId: j['taskId'] as String,
        startTime: DateTime.parse(j['startTime'] as String),
        endTime: j['endTime'] != null
            ? DateTime.parse(j['endTime'] as String)
            : null,
        status: j['status'] as String,
        periodLogs: (j['periodLogs'] as List<dynamic>?)
                ?.map((e) => PeriodLog.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

//
// JSON HELPERS
//
List<Task> tasksFromJson(String jsonStr) {
  final List<dynamic> decoded = json.decode(jsonStr) as List<dynamic>;
  return decoded.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
}

String tasksToJson(List<Task> tasks) =>
    json.encode(tasks.map((t) => t.toJson()).toList());
