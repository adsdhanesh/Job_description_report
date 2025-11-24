import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/task_manager.dart';
//import '../utils/time_utils.dart';
import 'task_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  String search = '';
  bool showFilters = false;
  int quickRangeDays = 7;
  bool compactMode = false;

  final Set<String> selectedIds = {};
  final Set<String> softDeletedIds = {}; // soft-deleted taskIds (in-memory)
  bool selectionMode = false;
  bool showDeleted = false;

  late AnimationController _controller;
  late Animation<double> fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _statBlock(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
      ]),
    );
  }

  int countActive(List tasks) {
    return tasks.where((t) {
      final s = (t.status ?? '').toLowerCase();
      return s.contains('active') || s.contains('running');
    }).length;
  }

  void _enterSelection(String taskId) {
    setState(() {
      selectionMode = true;
      selectedIds.add(taskId);
    });
  }

  void _toggleSelection(String taskId) {
    setState(() {
      if (selectedIds.contains(taskId))
        selectedIds.remove(taskId);
      else
        selectedIds.add(taskId);

      if (selectedIds.isEmpty) selectionMode = false;
    });
  }

  Future<void> _softDeleteSelected(TaskManager manager) async {
    if (selectedIds.isEmpty) return;

    final count = selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(count == 1 ? 'Delete task?' : 'Delete $count tasks?'),
        content: Text(
            'This will hide the selected task(s) from history. You can restore them from "Show deleted".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      softDeletedIds.addAll(selectedIds);
      selectedIds.clear();
      selectionMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted $count item${count > 1 ? 's' : ''}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              softDeletedIds.removeAll(softDeletedIds);
            });
          },
        ),
      ),
    );
  }

  Set<String> _lastDeletedSet = {};

  Future<void> _softDeleteSelectedWithUndo(TaskManager manager) async {
    if (selectedIds.isEmpty) return;

    final count = selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(count == 1 ? 'Delete task?' : 'Delete $count tasks?'),
        content: Text(
            'This will hide the selected task(s) from history. You can restore them from "Show deleted".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _lastDeletedSet = Set.from(selectedIds);
      softDeletedIds.addAll(selectedIds);
      selectedIds.clear();
      selectionMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted $count item${count > 1 ? 's' : ''}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              softDeletedIds.removeAll(_lastDeletedSet);
              _lastDeletedSet = {};
            });
          },
        ),
      ),
    );
  }

  Future<void> _restoreSelected(TaskManager manager) async {
    if (selectedIds.isEmpty) return;
    setState(() {
      softDeletedIds.removeAll(selectedIds);
      selectedIds.clear();
      selectionMode = false;
    });
  }

  Future<void> _permanentlyDeleteSelected(TaskManager manager) async {
    if (selectedIds.isEmpty) return;
    final count = selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Permanently delete $count item${count > 1 ? 's' : ''}?'),
        content: const Text(
            'This cannot be undone. It will remove tasks from storage.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    final idsToDel = Set<String>.from(selectedIds);
    bool persisted = false;

    try {} catch (_) {
      persisted = false;
    }

    if (!persisted) {
      setState(() {
        manager.tasks.removeWhere((t) => idsToDel.contains(t.taskId));
        selectedIds.clear();
        selectionMode = false;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Permanently deleted $count item${count > 1 ? 's' : ''}')));
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TaskManager>(context);
    final allTasks = manager.tasks;

    final now = DateTime.now();
    List filtered = allTasks.where((t) {
      final matchesSearch = search.isEmpty ||
          t.taskId.toLowerCase().contains(search.toLowerCase());

      if (quickRangeDays != 9999) {
        final dt = t.startTime;
        final diff = now.difference(dt).inDays;
        if (diff > quickRangeDays) return false;
      }

      // Soft-delete filter: hide deleted unless showDeleted true
      if (!showDeleted && softDeletedIds.contains(t.taskId)) return false;

      return matchesSearch;
    }).toList();

    // Sort newest first (by startTime)
    filtered.sort((a, b) {
      try {
        return (b.startTime as DateTime).compareTo(a.startTime as DateTime);
      } catch (_) {
        return 0;
      }
    });

    // Theme
    final primary = const Color(0xFF2962FF);
    final bg = const Color(0xFF0E1A2A);
    final cardColor = const Color(0xFF0F2438);
    final accentLight = const Color(0xFF63A4FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: selectionMode
            ? Text('${selectedIds.length} selected')
            : Row(children: [
                const Text('History'),
                const SizedBox(width: 12),
                if (showDeleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      Icon(Icons.delete, size: 16, color: primary),
                      const SizedBox(width: 8),
                      Text('Deleted', style: TextStyle(color: primary))
                    ]),
                  )
              ]),
        actions: [
          if (selectionMode) ...[
            IconButton(
              tooltip: 'Restore',
              icon: const Icon(Icons.restore_from_trash),
              onPressed: () => _restoreSelected(manager),
            ),
            IconButton(
              tooltip: 'Delete permanently',
              icon: const Icon(Icons.delete_forever),
              onPressed: () => _permanentlyDeleteSelected(manager),
            ),
            IconButton(
              tooltip: 'Cancel selection',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                selectionMode = false;
                selectedIds.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: Icon(showDeleted ? Icons.visibility_off : Icons.visibility,
                  color: accentLight),
              tooltip: showDeleted ? 'Hide deleted' : 'Show deleted',
              onPressed: () => setState(() => showDeleted = !showDeleted),
            ),
            IconButton(
              icon: Icon(Icons.filter_list, color: accentLight),
              onPressed: () => setState(() => showFilters = !showFilters),
            ),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(children: [
          // SEARCH & FILTER AREA
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: cardColor, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white70),
                    decoration: InputDecoration(
                      hintText: 'Search by task id',
                      hintStyle: TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => search = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: primary),
                  icon: const Icon(Icons.tune),
                  label: const Text('Filters'),
                  onPressed: () => setState(() => showFilters = !showFilters),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Toggle compact',
                  icon: Icon(compactMode ? Icons.view_list : Icons.view_agenda,
                      color: Colors.white70),
                  onPressed: () => setState(() => compactMode = !compactMode),
                ),
              ]),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: showFilters
                    ? Padding(
                        key: const ValueKey('filters'),
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(children: [
                          _chipButton(
                              'Today',
                              quickRangeDays == 0,
                              () => setState(() => quickRangeDays = 0),
                              primary),
                          const SizedBox(width: 8),
                          _chipButton(
                              '7 days',
                              quickRangeDays == 7,
                              () => setState(() => quickRangeDays = 7),
                              primary),
                          const SizedBox(width: 8),
                          _chipButton(
                              '30 days',
                              quickRangeDays == 30,
                              () => setState(() => quickRangeDays = 30),
                              primary),
                          const SizedBox(width: 8),
                          _chipButton(
                              'All',
                              quickRangeDays == 9999,
                              () => setState(() => quickRangeDays = 9999),
                              primary),
                          const Spacer(),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Range'),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Date range picker not implemented')));
                            },
                          )
                        ]),
                      )
                    : const SizedBox.shrink(),
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // SUMMARY ROW
          Row(children: [
            Expanded(child: _statBlock('Total Tasks', '${allTasks.length}')),
            const SizedBox(width: 12),
            Expanded(child: _statBlock('Shown', '${filtered.length}')),
            const SizedBox(width: 12),
            Expanded(child: _statBlock('Active', '${countActive(allTasks)}')),
          ]),

          const SizedBox(height: 12),

          // LIST
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.history, size: 68, color: Colors.white24),
                      const SizedBox(height: 8),
                      Text(
                          showDeleted ? 'No deleted tasks' : 'No history found',
                          style: const TextStyle(color: Colors.white54)),
                    ]),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final t = filtered[i];
                      final isSelected = selectedIds.contains(t.taskId);
                      final isDeleted = softDeletedIds.contains(t.taskId);

                      return AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        child: GestureDetector(
                          onLongPress: () {
                            if (!selectionMode) _enterSelection(t.taskId);
                          },
                          onTap: () {
                            if (selectionMode) {
                              _toggleSelection(t.taskId);
                            } else {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          TaskDetailsScreen(taskId: t.taskId)));
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.45),
                                      blurRadius: 6,
                                      offset: const Offset(0, 6))
                                ]),
                            child: Stack(children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  // selectable checkbox area
                                  if (selectionMode)
                                    Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: isSelected
                                            ? primary
                                            : Colors.white12,
                                        child: isSelected
                                            ? const Icon(Icons.check,
                                                size: 16, color: Colors.white)
                                            : null,
                                      ),
                                    ),
                                  // main content
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                                child: Text(
                                                    t.taskId ?? 'Untitled',
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xff080808),
                                                        fontWeight:
                                                            FontWeight.w700))),
                                            if (isDeleted)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                    color: Colors.white10,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                                child: const Text('Deleted',
                                                    style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12)),
                                              ),
                                          ]),
                                          const SizedBox(height: 6),
                                          Text(
                                              'Started: ${t.startTime.toString().split('.').first}',
                                              style: const TextStyle(
                                                  color: Colors.white70)),
                                          const SizedBox(height: 6),
                                          Text('Status: ${t.status}',
                                              style: const TextStyle(
                                                  color: Colors.blueAccent)),
                                        ]),
                                  ),
                                ]),
                              ),
                              // fade overlay when selected
                              if (isSelected)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.18),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
      // bottom action area for deletion when selectionMode is active
      bottomNavigationBar: selectionMode
          ? SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: cardColor,
                child: Row(children: [
                  Text('${selectedIds.length} selected',
                      style: const TextStyle(color: Colors.white)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      selectionMode = false;
                      selectedIds.clear();
                    }),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    label: const Text('Cancel',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    onPressed: () => _softDeleteSelectedWithUndo(manager),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                  ),
                ]),
              ),
            )
          : null,
    );
  }

  // chip helper
  Widget _chipButton(
      String label, bool active, VoidCallback onTap, Color primary) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: active ? primary : Colors.white10,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(color: active ? Colors.white : Colors.white70)),
      ),
    );
  }
}
