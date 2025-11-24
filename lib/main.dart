import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/task_manager.dart';
import 'providers/theme_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/new_task_screen.dart';
import 'screens/task_details_screen.dart';

void main() {
  runApp(const AppEntrypoint());
}

class AppEntrypoint extends StatelessWidget {
  const AppEntrypoint({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskManager()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const RootApp(),
    );
  }
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, theme, child) {
      final primary = const Color(0xFF2962FF);
      final cardColor = const Color(0xFF0F2438);

      final lightTheme = ThemeData(
        brightness: Brightness.light,
        primaryColor: primary,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
            backgroundColor: Colors.white, foregroundColor: primary),
        floatingActionButtonTheme:
            FloatingActionButtonThemeData(backgroundColor: primary),
      );

      final darkTheme = ThemeData(
        brightness: Brightness.dark,
        primaryColor: primary,
        scaffoldBackgroundColor: const Color(0xFF0E1A2A),
        appBarTheme: AppBarTheme(
            backgroundColor: cardColor, foregroundColor: Colors.white),
        floatingActionButtonTheme:
            FloatingActionButtonThemeData(backgroundColor: primary),
      );

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Job Report App',
        themeMode: theme.mode,
        theme: lightTheme,
        darkTheme: darkTheme,
        initialRoute: '/',
        routes: {
          '/': (_) => const DashboardScreen(),
          '/history': (_) => const HistoryScreen(),
          '/reports': (_) => const ReportsScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/new_task': (_) => const NewTaskScreen(),
        },
      );
    });
  }
}
