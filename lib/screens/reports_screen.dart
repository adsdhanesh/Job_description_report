import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/task_manager.dart';
import '../utils/time_utils.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime selectedDate = DateTime.now();
  int weekOffset = 0; // 0 = this week, -1 = last week, etc.
  bool showExporting = false;

  final Color primary = const Color(0xFF2962FF);
  final Color bg = const Color(0xFF0E1A2A);
  final Color cardColor = const Color(0xFF0F2438);
  final Color accentLight = const Color(0xFF63A4FF);

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TaskManager>(context);
    final tasks = manager.tasks;

    // Compute metrics
    final dailyTotals = _dailyTotals(tasks, selectedDate);
    final weeklyBuckets = _weeklyBuckets(tasks, weekOffset);
    final taskBreakdown = _taskBreakdown(tasks, selectedDate);

    final totalToday = dailyTotals['total'] as Duration;
    final idleToday = dailyTotals['idle'] as Duration;
    final activeToday = dailyTotals['active'] as Duration;
    final tasksCount =
        taskBreakdown.values.fold<int>(0, (p, e) => p + (e['count'] as int));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Text('Reports',
            style: TextStyle(color: accentLight, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Export summary',
            icon: const Icon(Icons.file_upload),
            color: accentLight,
            onPressed: showExporting
                ? null
                : () => _exportSummary(manager, dailyTotals, taskBreakdown),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top controls
          Row(children: [
            Expanded(child: _dateSelector()),
            const SizedBox(width: 12),
            _weekStepper(),
          ]),

          const SizedBox(height: 16),

          // Summary Cards
          SizedBox(
            height: 110,
            child: Row(children: [
              Expanded(
                  child: _summaryCard('Total Today', formatDuration(totalToday),
                      cardColor, accentLight)),
              const SizedBox(width: 12),
              Expanded(
                  child: _summaryCard('Active', formatDuration(activeToday),
                      cardColor, primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: _summaryCard('Idle', formatDuration(idleToday),
                      cardColor, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(
                  child: _summaryCard(
                      'Tasks', '${tasksCount}', cardColor, Colors.green)),
            ]),
          ),

          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Left column
            Expanded(
              flex: 2,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Week overview',
                        style: TextStyle(
                            color: accentLight, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Card(
                      color: cardColor,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          SizedBox(
                            height: 220,
                            child: _WeeklyBarChart(
                                buckets: weeklyBuckets, primary: primary),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            _miniStat(
                                'Week total',
                                formatDuration(_sumDurations(weeklyBuckets)),
                                primary),
                            const SizedBox(width: 12),
                            _miniStat(
                                'Avg/day',
                                formatDuration(Duration(
                                    minutes: (_sumDurations(weeklyBuckets)
                                            .inMinutes ~/
                                        7)))),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Hourly breakdown — ${_prettyDate(selectedDate)}',
                        style: TextStyle(
                            color: accentLight, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Card(
                      color: cardColor,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          height: 180,
                          child: _DailyLineChart(
                            tasks: tasks,
                            date: selectedDate,
                            manager: manager,
                            primary: primary,
                          ),
                        ),
                      ),
                    ),
                  ]),
            ),

            const SizedBox(width: 12),

            // Right column: Donut chart + legend
            Expanded(
              flex: 1,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Task breakdown',
                        style: TextStyle(
                            color: accentLight, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Card(
                      color: cardColor,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          height: 300,
                          child: Column(children: [
                            Expanded(
                              child: _DonutChart(
                                breakdown: taskBreakdown,
                                primary: primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                                child:
                                    _breakdownLegend(taskBreakdown, primary)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
            ),
          ]),

          const SizedBox(height: 20),

          // Export / actions
          Row(children: [
            ElevatedButton.icon(
              onPressed: () => _exportJson(manager),
              icon: const Icon(Icons.save_alt),
              label: const Text('Export JSON'),
              style: ElevatedButton.styleFrom(backgroundColor: primary),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  _showSharePreview(manager, dailyTotals, taskBreakdown),
              icon: const Icon(Icons.preview),
              label: const Text('Preview'),
            ),
          ]),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  // ---------------------------
  // UI helpers
  // ---------------------------
  Widget _dateSelector() {
    return Row(children: [
      OutlinedButton.icon(
        onPressed: () async {
          final dt = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (cx, child) => Theme(
                data: Theme.of(cx).copyWith(dialogBackgroundColor: cardColor),
                child: child!),
          );
          if (dt != null) setState(() => selectedDate = dt);
        },
        icon: const Icon(Icons.calendar_today),
        label: Text(_prettyDate(selectedDate)),
        style:
            OutlinedButton.styleFrom(side: BorderSide(color: Colors.white12)),
      ),
      const SizedBox(width: 12),
      TextButton(
        onPressed: () => setState(() => selectedDate = DateTime.now()),
        child: const Text('Today'),
      )
    ]);
  }

  Widget _weekStepper() {
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.chevron_left),
        color: Colors.white70,
        onPressed: () => setState(() => weekOffset--),
        tooltip: 'Previous week',
      ),
      Text('Week ${weekOffset == 0 ? 'This' : 'Offset $weekOffset'}',
          style: const TextStyle(color: Colors.white70)),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        color: Colors.white70,
        onPressed: () => setState(() => weekOffset++),
        tooltip: 'Next week',
      ),
    ]);
  }

  Widget _summaryCard(String title, String value, Color bgColor, Color accent) {
    return Card(
      color: bgColor,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        color: accentLight, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ])),
          Icon(Icons.assessment, color: accent),
        ]),
      ),
    );
  }

  Widget _miniStat(String label, String value, [Color? color]) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white10, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  Widget _breakdownLegend(
      Map<String, Map<String, Object>> breakdown, Color primary) {
    final entries = breakdown.entries.toList();
    if (entries.isEmpty) {
      return Center(
          child: Text('No tasks', style: TextStyle(color: Colors.white54)));
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final e = entries[i];
        final label = e.key;
        final duration = e.value['duration'] as Duration;
        final percent = e.value['percent'] as double;
        return Row(children: [
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: _colorForIndex(i),
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white))),
          Text(
              '${formatDuration(duration)} • ${(percent * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white70)),
        ]);
      },
    );
  }

  Future<void> _exportSummary(
      TaskManager manager,
      Map<String, Object> dailyTotals,
      Map<String, Map<String, Object>> breakdown) async {
    setState(() => showExporting = true);
    // simple text export (replace with file save later)
    final sb = StringBuffer();
    final dt = selectedDate;
    sb.writeln('Report - ${_prettyDate(dt)}');
    sb.writeln('Total: ${formatDuration(dailyTotals['total'] as Duration)}');
    sb.writeln('Active: ${formatDuration(dailyTotals['active'] as Duration)}');
    sb.writeln('Idle: ${formatDuration(dailyTotals['idle'] as Duration)}');
    sb.writeln('');
    sb.writeln('Task breakdown:');
    for (final e in breakdown.entries) {
      sb.writeln(e.key +
          ' - ' +
          formatDuration(e.value['duration'] as Duration) +
          ' (' +
          ((e.value['percent'] as double) * 100).toStringAsFixed(0) +
          '%)');
    }

    // show a dialog with the content (user can copy)
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Preview'),
        content: SingleChildScrollView(child: Text(sb.toString())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
    setState(() => showExporting = false);
  }

  Future<void> _exportJson(TaskManager manager) async {
    String jsonText;
    try {
      jsonText = await manager.exportJson();
    } catch (_) {
      jsonText = 'No JSON export available';
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('JSON Export Preview'),
        content: SingleChildScrollView(child: Text(jsonText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showSharePreview(TaskManager manager, Map<String, Object> dailyTotals,
      Map<String, Map<String, Object>> breakdown) {
    // quick preview snack
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview ready — open Export to copy/share')));
  }

  Map<String, Duration> _dailyTotals(List tasks, DateTime date) {
    Duration total = Duration.zero;
    Duration idle = Duration.zero;
    Duration active = Duration.zero;

    for (final t in tasks) {
      try {
        for (final p in (t.periodLogs as List)) {
          if (p == null) continue;
          final DateTime from = p.from;
          final DateTime to = p.to;
          // only count if same day at least partly
          if (!_overlapsDay(from, to, date)) continue;
          final fromC =
              (from.isBefore(DateTime(date.year, date.month, date.day))
                  ? DateTime(date.year, date.month, date.day)
                  : from);
          final toC =
              (to.isAfter(DateTime(date.year, date.month, date.day, 23, 59, 59))
                  ? DateTime(date.year, date.month, date.day, 23, 59, 59)
                  : to);
          final d = toC.difference(fromC);
          total += d;
          final status = (p.status ?? 'Active').toString().toLowerCase();
          if (status.contains('idle'))
            idle += d;
          else
            active += d;
        }
      } catch (_) {}
    }

    return {'total': total, 'idle': idle, 'active': active};
  }

  /// Weekly buckets (7 days) returning list of Durations (Mon..Sun)
  List<Duration> _weeklyBuckets(List tasks, int offset) {
    final now = DateTime.now();
    final startOfWeek = _startOfWeek(now).add(Duration(days: offset * 7));
    final buckets = List<Duration>.filled(7, Duration.zero);

    for (final t in tasks) {
      try {
        for (final p in (t.periodLogs as List)) {
          if (p == null) continue;
          final DateTime from = p.from;
          final DateTime to = p.to;
          // skip periods outside this week range
          if (to.isBefore(startOfWeek) ||
              from.isAfter(startOfWeek.add(const Duration(days: 7)))) continue;
          // intersect with each day
          for (int i = 0; i < 7; i++) {
            final dayStart = DateTime(
                startOfWeek.year, startOfWeek.month, startOfWeek.day + i);
            final dayEnd = DateTime(
                dayStart.year, dayStart.month, dayStart.day, 23, 59, 59);
            if (to.isBefore(dayStart) || from.isAfter(dayEnd)) continue;
            final fromC = from.isBefore(dayStart) ? dayStart : from;
            final toC = to.isAfter(dayEnd) ? dayEnd : to;
            buckets[i] += toC.difference(fromC);
          }
        }
      } catch (_) {}
    }
    return buckets;
  }

  Map<String, Map<String, Object>> _taskBreakdown(List tasks, DateTime date) {
    final Map<String, Duration> raw = {};
    Duration total = Duration.zero;

    for (final t in tasks) {
      try {
        Duration accum = Duration.zero;
        for (final p in (t.periodLogs as List)) {
          if (p == null) continue;
          if (!_overlapsDay(p.from, p.to, date)) continue;
          final fromC =
              p.from.isBefore(DateTime(date.year, date.month, date.day))
                  ? DateTime(date.year, date.month, date.day)
                  : p.from;
          final toC = p.to.isAfter(
                  DateTime(date.year, date.month, date.day, 23, 59, 59))
              ? DateTime(date.year, date.month, date.day, 23, 59, 59)
              : p.to;
          accum += toC.difference(fromC);
        }
        if (accum > Duration.zero) {
          raw[t.taskId] = (raw[t.taskId] ?? Duration.zero) + accum;
          total += accum;
        }
      } catch (_) {}
    }

    final Map<String, Map<String, Object>> out = {};
    final entries = raw.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value)); // largest first

    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final dur = e.value;
      final pct = total.inMilliseconds == 0
          ? 0.0
          : dur.inMilliseconds / total.inMilliseconds;
      out[e.key] = {'duration': dur, 'percent': pct, 'count': 1};
    }

    return out;
  }

  bool _overlapsDay(DateTime from, DateTime to, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
    return !(to.isBefore(dayStart) || from.isAfter(dayEnd));
  }

  DateTime _startOfWeek(DateTime d) {
    final monday = d.subtract(Duration(days: (d.weekday + 6) % 7));
    return DateTime(monday.year, monday.month, monday.day);
  }

  Duration _sumDurations(List<Duration> ds) {
    Duration acc = Duration.zero;
    for (final d in ds) acc += d;
    return acc;
  }

  String _prettyDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Color _colorForIndex(int i) {
    final palette = [
      const Color(0xFF2962FF),
      const Color(0xFF63A4FF),
      const Color(0xFF00E676),
      const Color(0xFFFFA726),
      const Color(0xFFAB47BC),
      const Color(0xFFFF7043),
      const Color(0xFF8D6E63),
    ];
    return palette[i % palette.length];
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<Duration> buckets;
  final Color primary;
  const _WeeklyBarChart(
      {required this.buckets, required this.primary, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxMin = buckets
        .map((d) => d.inMinutes.toDouble())
        .fold<double>(0.0, (a, b) => a > b ? a : b);
    final maxY = (maxMin <= 10) ? 10.0 : (maxMin * 1.2);

    final bars = List.generate(buckets.length, (i) {
      final minutes = buckets[i].inMinutes.toDouble();
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: minutes,
            color: primary,
            width: 14,
            borderRadius: BorderRadius.circular(6))
      ]);
    });

    return BarChart(BarChartData(
      barGroups: bars,
      maxY: maxY,
      gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.white12, strokeWidth: 0.5)),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final labels = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun'
                  ];
                  final idx = v.toInt();
                  if (idx < 0 || idx >= labels.length)
                    return const SizedBox.shrink();
                  return Text(labels[idx],
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12));
                })),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, meta) {
                  return Text('${v.toInt()}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10));
                })),
      ),
      borderData: FlBorderData(show: false),
    ));
  }
}

class _DailyLineChart extends StatelessWidget {
  final List tasks;
  final DateTime date;
  final TaskManager manager;
  final Color primary;
  const _DailyLineChart(
      {required this.tasks,
      required this.date,
      required this.manager,
      required this.primary,
      Key? key})
      : super(key: key);

  // Construct hourly buckets 0..23
  List<double> _hourBuckets() {
    final buckets = List<double>.filled(24, 0.0);
    try {
      for (final t in tasks) {
        for (final p in (t.periodLogs as List)) {
          if (p == null) continue;
          final from = p.from;
          final to = p.to;
          if (!(from.day == date.day &&
                  from.month == date.month &&
                  from.year == date.year) &&
              !(to.day == date.day &&
                  to.month == date.month &&
                  to.year == date.year) &&
              !(from.isBefore(date) && to.isAfter(date))) continue;

          // clamp into day
          final dayStart = DateTime(date.year, date.month, date.day);
          final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);
          final fromC = from.isBefore(dayStart) ? dayStart : from;
          final toC = to.isAfter(dayEnd) ? dayEnd : to;

          DateTime cursor = fromC;
          while (cursor.isBefore(toC)) {
            final nextHour =
                DateTime(cursor.year, cursor.month, cursor.day, cursor.hour)
                    .add(const Duration(hours: 1));
            final segmentEnd = nextHour.isBefore(toC) ? nextHour : toC;
            final minutes = segmentEnd.difference(cursor).inMinutes.toDouble();
            buckets[cursor.hour] += minutes;
            cursor = segmentEnd;
          }
        }
      }
    } catch (_) {}
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _hourBuckets();
    final spots = List<FlSpot>.generate(
        buckets.length, (i) => FlSpot(i.toDouble(), buckets[i]));
    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);
    final yUpper = (maxY <= 10) ? 10.0 : (maxY * 1.2);

    return LineChart(LineChartData(
      minX: 0,
      maxX: 23,
      minY: 0,
      maxY: yUpper,
      gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.white12, strokeWidth: 0.5)),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                interval: 3,
                getTitlesWidget: (v, meta) {
                  final intVal = v.toInt();
                  if (intVal % 3 != 0) return const SizedBox.shrink();
                  return Text('$intVal',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10));
                })),
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, meta) {
                  return Text(v.toInt().toString(),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10));
                })),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: primary,
          barWidth: 3,
          dotData: FlDotData(show: false),
          belowBarData:
              BarAreaData(show: true, color: primary.withOpacity(0.18)),
        ),
      ],
    ));
  }
}

class _DonutChart extends StatelessWidget {
  final Map<String, Map<String, Object>> breakdown;
  final Color primary;
  const _DonutChart({required this.breakdown, required this.primary, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final entries = breakdown.entries.toList();
    if (entries.isEmpty) {
      return Center(
          child: Text('No data', style: TextStyle(color: Colors.white54)));
    }

    final total = entries.fold<int>(
        0, (p, e) => p + (e.value['duration'] as Duration).inMinutes);

    final pies = List<PieChartSectionData>.generate(entries.length, (i) {
      final e = entries[i];
      final dur = e.value['duration'] as Duration;

      final color = _palette[i % _palette.length];
      return PieChartSectionData(
        value: dur.inMinutes.toDouble(),
        color: color,
        title: '${((dur.inMinutes / total) * 100).toStringAsFixed(0)}%',
        radius: 48,
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      );
    });

    return PieChart(
        PieChartData(sections: pies, centerSpaceRadius: 28, sectionsSpace: 4));
  }

  static const List<Color> _palette = [
    Color(0xFF2962FF),
    Color(0xFF63A4FF),
    Color(0xFF00E676),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF8D6E63),
  ];
}
