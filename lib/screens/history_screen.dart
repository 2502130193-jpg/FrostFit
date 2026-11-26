import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}
class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Workout>> _future;
  @override
  void initState() { super.initState(); _load(); }
  void _load() => _future = DatabaseService.instance.getWorkouts();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historial de actividad', style: TextStyle(fontWeight: FontWeight.w800))),
    body: FutureBuilder<List<Workout>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final workouts = snapshot.data ?? [];
        if (workouts.isEmpty) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.snowshoeing, size: 55, color: AppTheme.mint),
          SizedBox(height: 12), Text('Todavía no hay entrenamientos'),
          SizedBox(height: 5), Text('Tu primera sesión aparecerá aquí.', style: TextStyle(color: AppTheme.muted)),
        ]));
        final steps = workouts.fold<int>(0, (s, w) => s + w.steps);
        final km = workouts.fold<double>(0, (s, w) => s + w.distanceMeters) / 1000;
        return RefreshIndicator(
          onRefresh: () async { setState(_load); await _future; },
          child: ListView(padding: const EdgeInsets.all(18), children: [
            Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _summary('SESIONES', '${workouts.length}'),
                _summary('PASOS', '$steps'),
                _summary('KM', km.toStringAsFixed(2)),
              ]),
            ),
            const SizedBox(height: 18),
            ...workouts.map((w) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: AppTheme.forest, child: Icon(Icons.directions_run, color: AppTheme.mint)),
                title: Text(DateFormat('dd/MM/yyyy · HH:mm').format(w.date), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${w.steps} pasos  •  ${(w.distanceMeters / 1000).toStringAsFixed(2)} km  •  ${w.durationSeconds ~/ 60} min'),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
              ),
            )),
          ]),
        );
      },
    ),
  );

  Widget _summary(String label, String value) => Column(children: [
    Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.mint)),
    const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.muted)),
  ]);
}
