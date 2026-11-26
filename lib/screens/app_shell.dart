import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: IndexedStack(
      index: _index,
      children: [
        DashboardScreen(isVisible: _index == 0),
        const HistoryScreen(),
        const ProfileScreen(),
      ],
    )),
    bottomNavigationBar: NavigationBar(
      backgroundColor: AppTheme.panel,
      indicatorColor: AppTheme.mint.withOpacity(.16),
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Inicio'),
        NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Historial'),
        NavigationDestination(icon: Icon(Icons.fingerprint_rounded), label: 'Perfil'),
      ],
    ),
  );
}
