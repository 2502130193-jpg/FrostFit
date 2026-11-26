class Workout {
  final int? id;
  final DateTime date;
  final int durationSeconds;
  final int steps;
  final double distanceMeters;
  final List<List<double>> route;

  const Workout({
    this.id, required this.date, required this.durationSeconds,
    required this.steps, required this.distanceMeters, required this.route,
  });

  Map<String, Object?> toMap() => {
    'id': id, 'date': date.toIso8601String(),
    'duration_seconds': durationSeconds, 'steps': steps,
    'distance_meters': distanceMeters,
    'route': route.map((p) => '${p[0]},${p[1]}').join(';'),
  };

  factory Workout.fromMap(Map<String, Object?> map) {
    final raw = (map['route'] as String?) ?? '';
    final points = raw.isEmpty ? <List<double>>[] : raw.split(';').map((s) {
      final p = s.split(',');
      return <double>[double.parse(p[0]), double.parse(p[1])];
    }).toList();
    return Workout(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      durationSeconds: map['duration_seconds'] as int,
      steps: map['steps'] as int,
      distanceMeters: (map['distance_meters'] as num).toDouble(),
      route: points,
    );
  }
}
