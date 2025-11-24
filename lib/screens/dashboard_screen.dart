import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/task_manager.dart';
import '../utils/time_utils.dart';
import '../widgets/task_card.dart';
import 'task_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  Timer? idleTimer;
  Timer? hourlyTimer;
  DateTime lastUserActivity = DateTime.now();
  DateTime lastLifecycle = DateTime.now();

  Duration idleLimit = const Duration(minutes: 5);

  late FocusNode _focusNode;

  // store previous total for smooth tween animations
  Duration _previousTotal = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _focusNode = FocusNode();

    startIdleTimer();
    startHourlyTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    idleTimer?.cancel();
    hourlyTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void startIdleTimer() {
    idleTimer?.cancel();

    idleTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final diff = DateTime.now().difference(lastUserActivity);

      if (diff >= idleLimit) {
        try {
          final manager = Provider.of<TaskManager>(context, listen: false);
          if (manager.tasks.isNotEmpty) {
            final current = manager.tasks.last;

            if (current.status != "Idle") {
              manager.markIdle(current, lastUserActivity);
            }
          }
        } catch (e) {
          // defensive: if Provider isn't available or another error occurs, ignore
        }
      }
    });
  }

  void resetIdle() {
    lastUserActivity = DateTime.now();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final gap = now.difference(lastLifecycle);

      if (gap > idleLimit) {
        try {
          final manager = Provider.of<TaskManager>(context, listen: false);

          if (manager.tasks.isNotEmpty) {
            manager.recoverFromSleep(manager.tasks.last, gap);
          }
        } catch (e) {}
      }
      lastLifecycle = now;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      hourlyTimer?.cancel();
      hourlyTimer = null;
    }
  }

  void startHourlyTimer() {
    hourlyTimer?.cancel();
    final now = DateTime.now();
    final msToNextHour = DateTime(now.year, now.month, now.day, now.hour + 1)
        .difference(now)
        .inMilliseconds;

    Future.delayed(Duration(milliseconds: msToNextHour), () {
      if (!mounted) return;
      askHourlyDescription();
      hourlyTimer = Timer.periodic(const Duration(hours: 1), (_) {
        if (!mounted) return;
        askHourlyDescription();
      });
    });
  }

  void askHourlyDescription() async {
    if (!mounted) return;

    final route = ModalRoute.of(context);
    if (route == null || !(route.isCurrent)) return;

    final manager = Provider.of<TaskManager>(context, listen: false);
    if (manager.tasks.isEmpty) return;

    final current = manager.tasks.last;
    final ctl = TextEditingController();

    final desc = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hourly Work Description"),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            hintText: "What did you work on this hour?",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, null);
            },
            child: const Text("Skip"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    ctl.dispose();

    if (desc != null && desc.trim().isNotEmpty) {
      try {
        manager.logHourlyWork(current, desc);
      } catch (e) {}
    }
  }

  Duration totalWorkedAcrossTasks(List tasks, TaskManager manager) {
    Duration total = Duration.zero;
    for (final t in tasks) {
      total += manager.totalActiveDurationForTask(t);
    }
    return total;
  }

  int countActive(List tasks) {
    try {
      return tasks
          .where((t) => t.status != "Inactive" && t.status != "Idle")
          .length;
    } catch (_) {
      return 0;
    }
  }

  int countCompleted(List tasks) {
    try {
      return tasks
          .where((t) => t.status == "Inactive" || t.status == "Completed")
          .length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TaskManager>(context);
    final tasks = manager.tasks;

    final primary = const Color(0xFF2962FF); // Neon tech blue
    final bg = const Color(0xFF0E1A2A); // dark background
    final cardColor = const Color(0xFF0F2438); // card surface (dark)
    final accentLight = const Color(0xFF63A4FF);

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (_) => resetIdle(),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTapDown: (_) => resetIdle(),
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: cardColor,
            elevation: 0,
            title: Row(
              children: [
                Text('Job Report Dashboard',
                    style: TextStyle(
                        color: accentLight, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Icon(Icons.timeline, size: 16, color: primary),
                    const SizedBox(width: 8),
                    Text('Overview', style: TextStyle(color: primary))
                  ]),
                ),
              ],
            ),
            actions: [
              IconButton(
                  icon: const Icon(Icons.bar_chart),
                  color: accentLight,
                  tooltip: 'Reports',
                  onPressed: () => Navigator.pushNamed(context, '/reports')),
              IconButton(
                  icon: const Icon(Icons.history),
                  color: accentLight,
                  tooltip: 'History',
                  onPressed: () => Navigator.pushNamed(context, '/history')),
              IconButton(
                  icon: const Icon(Icons.settings),
                  color: accentLight,
                  tooltip: 'Settings',
                  onPressed: () => Navigator.pushNamed(context, '/settings')),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: AnimatedScale(
            duration: const Duration(milliseconds: 250),
            scale: 1.0,
            child: FloatingActionButton(
              backgroundColor: primary,
              onPressed: () {
                if (tasks.isNotEmpty && tasks.last.status != 'Inactive') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                          'Close the current task before creating a new one.')));
                  return;
                }
                Navigator.pushNamed(context, '/new_task');
              },
              child: const Icon(Icons.add),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(tasks, manager, cardColor, accentLight, primary),
                const SizedBox(height: 16),
                SizedBox(
                  height: 260,
                  child: _HourlyLineChartCard(
                    bg: cardColor,
                    primary: primary,
                    accentLight: accentLight,
                    tasks: tasks,
                    manager: manager,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _SummaryCardCompact(
                            bg: cardColor,
                            accentLight: accentLight,
                            primary: primary,
                            tasks: tasks,
                            manager: manager),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _TasksBarCard(
                            bg: cardColor,
                            primary: primary,
                            accentLight: accentLight,
                            tasks: tasks,
                            manager: manager),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Tasks',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: accentLight)),
                    Text('${tasks.length} tasks',
                        style: TextStyle(color: Colors.grey[400])),
                  ],
                ),
                const SizedBox(height: 8),
                if (tasks.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.task_alt, size: 60, color: Colors.grey[800]),
                        const SizedBox(height: 12),
                        const Text('No tasks yet — tap + to start',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white70)),
                      ],
                    ),
                  )
                else
                  Column(
                    children: List.generate(tasks.length, (i) {
                      final t = tasks[i];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      TaskDetailsScreen(taskId: t.taskId))),
                          child: Container(
                            decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 6))
                                ]),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: TaskCard(
                                task: t,
                                onAddHourDesc: () async {
                                  if (t.status == 'Inactive') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Task is already closed.')));
                                    return;
                                  }

                                  final ctl = TextEditingController();
                                  final desc = await showDialog<String?>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Add description'),
                                      content: TextField(
                                        controller: ctl,
                                        decoration: const InputDecoration(
                                            hintText: 'Description'),
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, null),
                                            child: const Text('Cancel')),
                                        ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, ctl.text),
                                            child: const Text('Save')),
                                      ],
                                    ),
                                  );

                                  // dispose
                                  ctl.dispose();

                                  if (desc != null && desc.trim().isNotEmpty) {
                                    manager.closePeriod(t, description: desc);
                                    manager.startNewActivePeriod(t,
                                        description: desc);
                                  }
                                },
                                onClose: () async {
                                  if (t.status == 'Inactive') return;

                                  await manager.endTask(t);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('${t.taskId} closed')),
                                  );
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard(List tasks, TaskManager manager, Color cardColor,
      Color accentLight, Color primary) {
    final total = totalWorkedAcrossTasks(tasks, manager);
    final active = countActive(tasks);

    final tweenBegin = _previousTotal;
    _previousTotal = total;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total Worked',
                style:
                    TextStyle(color: accentLight, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TweenAnimationBuilder<Duration>(
              tween: Tween(begin: tweenBegin, end: total),
              duration: const Duration(milliseconds: 700),
              builder: (context, value, child) {
                return Text(formatDuration(value),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white));
              },
            ),
          ]),
          Row(children: [
            _tinyStat('Active', active.toString()),
            const SizedBox(width: 12),
            Icon(Icons.timer, size: 36, color: primary),
          ]),
        ],
      ),
    );
  }

  Widget _tinyStat(String label, String value) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
            color: Colors.white12, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12))
        ]));
  }
}

class _HourlyLineChartCard extends StatelessWidget {
  final Color bg;
  final Color primary;
  final Color accentLight;
  final List tasks;
  final TaskManager manager;

  const _HourlyLineChartCard({
    required this.bg,
    required this.primary,
    required this.accentLight,
    required this.tasks,
    required this.manager,
    Key? key,
  }) : super(key: key);

  List<double> _hourBuckets() {
    final buckets = List<double>.filled(24, 0.0);
    final now = DateTime.now();

    for (final t in tasks) {
      try {
        List periods = [];
        try {
          if (t.periods != null) periods = List.from(t.periods);
        } catch (_) {
          try {
            if (t.activePeriods != null) periods = List.from(t.activePeriods);
          } catch (_) {
            periods = [];
          }
        }

        if (periods.isNotEmpty) {
          for (final p in periods) {
            DateTime? s;
            DateTime? e;
            try {
              s = p['start'] ?? p.start;
            } catch (_) {}
            try {
              e = p['end'] ?? p.end;
            } catch (_) {}

            // if end is null, use now
            if (s == null) continue;
            e ??= DateTime.now();

            final isToday =
                s.year == now.year && s.month == now.month && s.day == now.day;
            if (!isToday) continue;

            // distribute minutes across covered hours
            DateTime iter = DateTime(s.year, s.month, s.day, s.hour, s.minute);
            while (iter.isBefore(e)) {
              final hourEnd =
                  DateTime(iter.year, iter.month, iter.day, iter.hour + 1);
              final chunkEnd = e.isBefore(hourEnd) ? e : hourEnd;
              final minutes = chunkEnd.difference(iter).inMinutes.toDouble();
              buckets[iter.hour.clamp(0, 23)] += minutes;
              iter = chunkEnd;
            }
          }
          continue;
        }

        // fallback: use startTime and total duration
        DateTime? dt;
        try {
          dt = t.startTime;
        } catch (_) {
          dt = null;
        }

        final durMin =
            manager.totalActiveDurationForTask(t).inMinutes.toDouble();
        if (dt != null) {
          final isToday =
              dt.year == now.year && dt.month == now.month && dt.day == now.day;
          if (isToday) {
            // Distribute evenly across the hours spanned by the duration
            if (durMin <= 0) {
              buckets[dt.hour.clamp(0, 23)] += 0.0;
            } else {
              // approximate end
              final end = dt.add(Duration(minutes: durMin.toInt()));
              DateTime iter =
                  DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
              while (iter.isBefore(end)) {
                final hourEnd =
                    DateTime(iter.year, iter.month, iter.day, iter.hour + 1);
                final chunkEnd = end.isBefore(hourEnd) ? end : hourEnd;
                final minutes = chunkEnd.difference(iter).inMinutes.toDouble();
                buckets[iter.hour.clamp(0, 23)] += minutes;
                iter = chunkEnd;
              }
            }
            continue;
          }
        }

        buckets[now.hour] += durMin;
      } catch (_) {}
    }
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _hourBuckets();
    final spots = List<FlSpot>.generate(
        buckets.length, (i) => FlSpot(i.toDouble(), buckets[i]));
    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);
    final yUpper = (maxY <= 10) ? 10.0 : (maxY * 1.2);

    return Card(
      color: bg,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today — Hours by hour',
              style:
                  TextStyle(color: accentLight, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 23,
                minY: 0,
                maxY: yUpper,
                gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: Colors.white24, strokeWidth: 0.5)),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          interval: 4,
                          getTitlesWidget: (value, meta) {
                            final v = value.toInt();
                            if (v % 4 != 0) return const SizedBox.shrink();
                            return Text('$v',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 10));
                          })),
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toInt().toString(),
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 10));
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
                    belowBarData: BarAreaData(
                        show: true, color: primary.withOpacity(0.18)),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SummaryCardCompact extends StatelessWidget {
  final Color bg;
  final Color accentLight;
  final Color primary;
  final List tasks;
  final TaskManager manager;

  const _SummaryCardCompact(
      {required this.bg,
      required this.accentLight,
      required this.primary,
      required this.tasks,
      required this.manager,
      Key? key})
      : super(key: key);

  Duration _totalWorkedAcrossTasks() {
    Duration total = Duration.zero;
    for (final t in tasks) {
      total += manager.totalActiveDurationForTask(t);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalWorkedAcrossTasks();
    final active =
        tasks.where((t) => t.status != 'Inactive' && t.status != 'Idle').length;

    return Card(
      color: bg,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Work Summary',
              style:
                  TextStyle(color: accentLight, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(formatDuration(total),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Tasks', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('${tasks.length}',
                      style: const TextStyle(color: Colors.white))
                ])),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Active', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('$active', style: const TextStyle(color: Colors.white))
                ])),
          ]),
          const SizedBox(height: 8),
          Expanded(
              child: Center(
                  child: Text('Keep pushing — small wins add up',
                      style: TextStyle(color: Colors.white54)))),
        ]),
      ),
    );
  }
}

class _TasksBarCard extends StatelessWidget {
  final Color bg;
  final Color primary;
  final Color accentLight;
  final List tasks;
  final TaskManager manager;

  const _TasksBarCard(
      {required this.bg,
      required this.primary,
      required this.accentLight,
      required this.tasks,
      required this.manager,
      Key? key})
      : super(key: key);

  List<BarChartGroupData> _makeBars() {
    final now = DateTime.now();
    // simple: group tasks by created/start day (use startTime)
    List filtered = tasks.where((t) {
      try {
        final dt = t.startTime;
        if (dt == null) return false;
        return dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day;
      } catch (_) {
        return false;
      }
    }).toList();

    if (filtered.isEmpty) filtered = tasks;

    final chosen = filtered.take(7).toList();

    final bars = <BarChartGroupData>[];

    for (int i = 0; i < chosen.length; i++) {
      final t = chosen[i];
      final value = manager.totalActiveDurationForTask(t).inMinutes.toDouble();
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
            toY: value,
            color: primary,
            width: 12,
            borderRadius: BorderRadius.circular(6))
      ]));
    }
    return bars;
  }

  @override
  Widget build(BuildContext context) {
    final bars = _makeBars();
    final maxY = bars.isEmpty
        ? 1.0
        : (bars
                .map((b) => b.barRods.first.toY)
                .fold(0.0, (a, b) => a > b ? a : b) +
            1);

    return Card(
      color: bg,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tasks Today',
              style:
                  TextStyle(color: accentLight, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: bars.isEmpty
                ? Center(
                    child: Text('No recent tasks',
                        style: TextStyle(color: Colors.white54)))
                : BarChart(
                    BarChartData(
                      barGroups: bars,
                      maxY: maxY,
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(show: false),
                      alignment: BarChartAlignment.spaceAround,
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}
