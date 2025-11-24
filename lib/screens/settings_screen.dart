// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/task_manager.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TaskManager>(context, listen: false);
    final theme = Provider.of<ThemeProvider>(context);

    final Color primary = const Color(0xFF2962FF);
    final Color cardColor = const Color(0xFF0F2438);
    final Color bg = const Color(0xFF0E1A2A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardColor,
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Theme toggle card
          Card(
            color: cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: const Text('Theme',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(theme.isDark ? 'Dark' : 'Light'),
              trailing: Switch(
                value: theme.isDark,
                activeColor: primary,
                onChanged: (v) {
                  theme.setDark(v);
                  // optional: persist theme using provider.save() if implemented
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Export JSON
          Card(
            color: cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Export JSON'),
              subtitle: const Text('Export all tasks to a JSON file / preview'),
              onTap: () async {
                final jsonText = await manager.exportJson();
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('JSON Export'),
                    content: SingleChildScrollView(child: Text(jsonText)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close')),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Clear all data
          Card(
            color: cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Clear all data'),
              subtitle: const Text('Deletes all tasks and history'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm clear all'),
                    content: const Text(
                        'This will delete all tasks and cannot be undone.'),
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

                if (confirmed == true) {
                  await manager.clearAll();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All data cleared')));
                }
              },
            ),
          ),

          const SizedBox(height: 12),

          // Reset app (alias to clear + reset theme)
          Card(
            color: cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reset app'),
              subtitle: const Text('Clear data and reset to defaults'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset app'),
                    content: const Text(
                        'This will clear data and reset settings to defaults. Continue?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Reset')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await manager.clearAll();
                  theme.setDark(true); // back to default dark
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('App reset to defaults')));
                }
              },
            ),
          ),

          const SizedBox(height: 18),

          // App info
          Card(
            color: cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('App Info',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('job_report_app — version 1.0.0'),
                    SizedBox(height: 4),
                    Text('Developed by you'),
                  ]),
            ),
          ),

          const Spacer(),

          // Small footer
          Center(
            child:
                Text('Made with ❤️', style: TextStyle(color: Colors.white54)),
          )
        ]),
      ),
    );
  }
}
