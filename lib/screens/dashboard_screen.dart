import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/workout.dart';
import '../models/frost_profile.dart';
import '../widgets/frost_widgets.dart';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final bool isVisible;
  const DashboardScreen({super.key, this.isVisible = true});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<Position>? _gpsSub;
  final List<LatLng> _route = [];
  int _steps = 0, _baseSteps = 0, _seconds = 0;
  double _ax = 0, _ay = 0, _az = 0, _gx = 0, _gy = 0, _gz = 0;
  double _distance = 0, _gpsDistance = 0, _estimatedDistance = 0;
  double _roll = 0, _pitch = 0, _speedKmh = 0;
  DateTime? _lastGyroAt;
  String _movement = 'En reposo';
  bool _running = false, _paused = false, _availableSteps = true;
  Timer? _timer;
  DateTime? _startedAt;
  Position? _position;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    frostProfile.addListener(_onProfile);
  }

  void _onProfile() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible && !widget.isVisible) {
      // Al cambiar de pestaña se liberan los listeners y el GPS.
      _stopStreams();
    } else if (!oldWidget.isVisible && widget.isVisible && _running && !_paused) {
      _startStreams();
    }
  }

  @override
  void dispose() {
    frostProfile.removeListener(_onProfile);
    WidgetsBinding.instance.removeObserver(this);
    _stopStreams();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Los sensores de movimiento se liberan al ir a segundo plano.
      // El GPS puede continuar mediante el servicio foreground de Android.
      _stopMotionSensors();
    } else if (state == AppLifecycleState.resumed && _running && !_paused) {
      _startMotionSensors();
      _startTimer();
    }
  }

  Future<bool> _showPermissionRationale() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.panel,
        title: const Text('Permisos para entrenar'),
        content: const Text('FrostFit necesita Actividad física para contar pasos y Ubicación para medir velocidad, distancia y dibujar tu ruta. Si autorizas ubicación «todo el tiempo», el GPS podrá continuar con una notificación cuando minimices la app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
        ],
      ),
    );
    return accepted ?? false;
  }

  Future<void> _startWorkout() async {
    if (!await _showPermissionRationale() || !mounted) return;
    final activity = await PermissionService.requestActivity();
    final location = await PermissionService.requestBackgroundLocation();
    if (!mounted) return;
    if (!location) {
      _message('Concede ubicación. Para registrar la ruta con la app minimizada, habilita también «Permitir todo el tiempo» en Ajustes.');
      return;
    }
    if (!activity) _message('Sin permiso de actividad física: el podómetro podría no estar disponible.');
    setState(() {
      _running = true; _paused = false; _seconds = 0; _steps = 0;
      _baseSteps = 0; _distance = 0; _gpsDistance = 0; _estimatedDistance = 0;
      _roll = 0; _pitch = 0; _speedKmh = 0; _lastGyroAt = null;
      _route.clear(); _startedAt = DateTime.now();
    });
    _startStreams();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _running && !_paused) setState(() => _seconds++);
    });
  }

  void _startStreams() {
    _startMotionSensors();
    _gpsSub?.cancel();
    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'FrostFit · entrenamiento activo',
        notificationText: 'Registrando tu recorrido GPS',
        enableWakeLock: true,
        setOngoing: true,
      ),
    )
        : const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
    _gpsSub = Geolocator.getPositionStream(locationSettings: settings).listen((p) {
      if (!mounted || !_running || _paused) return;
      setState(() {
        if (_position != null) {
          final delta = Geolocator.distanceBetween(
            _position!.latitude, _position!.longitude,
            p.latitude, p.longitude,
          );
          // Filtra saltos GPS improbables para evitar distancias falsas.
          if (delta >= 1 && delta < 100) _gpsDistance += delta;
        }
        _position = p;
        _speedKmh = math.max(0, p.speed * 3.6).toDouble();
        _route.add(LatLng(p.latitude, p.longitude));
        // GPS es la fuente principal; los pasos dan una estimación si no hay fix GPS.
        _estimatedDistance = _steps * frostProfile.strideM;
        _distance = _gpsDistance > 0 ? _gpsDistance : _estimatedDistance;
      });
    }, onError: (_) => _message('No fue posible obtener la ubicación GPS.'));
  }

  void _startMotionSensors() {
    _stepSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    try {
      _stepSub = Pedometer.stepCountStream.listen((event) {
        if (!mounted || !_running || _paused) return;
        setState(() {
          if (_baseSteps == 0) _baseSteps = event.steps;
          _steps = math.max(0, event.steps - _baseSteps).toInt();
          _estimatedDistance = _steps * frostProfile.strideM;
          if (_gpsDistance == 0) _distance = _estimatedDistance;
        });
      }, onError: (_) { if (mounted) setState(() => _availableSteps = false); });
    } catch (_) { _availableSteps = false; }

    try {
      _accelSub = accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 200)).listen((e) {
        if (!mounted || !_running || _paused) return;
        // La aceleración dinámica aproxima la magnitud quitando la gravedad (9.81 m/s²).
        final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        final dynamicAcceleration = (magnitude - 9.81).abs();
        setState(() {
          _ax = e.x; _ay = e.y; _az = e.z;
          _movement = dynamicAcceleration < 0.8 ? 'En reposo' :
          dynamicAcceleration < 2.5 ? 'Caminata' :
          dynamicAcceleration < 5.0 ? 'Trote' : 'Movimiento intenso';
        });
      }, onError: (_) { if (mounted) setState(() => _movement = 'Acelerómetro no disponible'); });
    } catch (_) { if (mounted) setState(() => _movement = 'Acelerómetro no disponible'); }

    try {
      _gyroSub = gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 200)).listen((e) {
        if (!mounted || !_running || _paused) return;
        final now = DateTime.now();
        final double dt = _lastGyroAt == null ? 0.0 : (now.difference(_lastGyroAt!).inMilliseconds / 1000).clamp(0.0, 0.2).toDouble();
        _lastGyroAt = now;
        setState(() {
          _gx = e.x; _gy = e.y; _gz = e.z;
          // Integración aproximada de velocidad angular para mostrar orientación relativa.
          _roll = (_roll + e.x * dt) % (2 * math.pi);
          _pitch = (_pitch + e.y * dt) % (2 * math.pi);
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _stopMotionSensors() async {
    await _stepSub?.cancel(); _stepSub = null;
    await _accelSub?.cancel(); _accelSub = null;
    await _gyroSub?.cancel(); _gyroSub = null;
  }

  Future<void> _stopStreams() async {
    await _stopMotionSensors();
    await _gpsSub?.cancel(); _gpsSub = null;
  }

  Future<void> _togglePause() async {
    if (_paused) {
      setState(() => _paused = false);
      _startStreams(); _startTimer();
    } else {
      setState(() => _paused = true);
      _timer?.cancel(); await _stopStreams();
    }
  }

  Future<void> _finishWorkout() async {
    _timer?.cancel();
    await _stopStreams();
    if (_seconds > 0) {
      await DatabaseService.instance.saveWorkout(Workout(
        date: _startedAt ?? DateTime.now(),
        durationSeconds: _seconds, steps: _steps,
        distanceMeters: _distance, route: _route.map((p) => [p.latitude, p.longitude]).toList(),
      ));
    }
    if (!mounted) return;
    setState(() { _running = false; _paused = false; _position = null; });
    _message('Entrenamiento guardado en tu historial.');
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _time() {
    final h = (_seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final center = _position == null
        ? const LatLng(19.7, -99.0)
        : LatLng(_position!.latitude, _position!.longitude);
    return Stack(children: [
      Positioned.fill(child: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          sliver: SliverList(delegate: SliverChildListDelegate([
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('FROSTFIT  ✦', style: TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w900, letterSpacing: 2)),
                SizedBox(height: 5),
                Text('Entrena con espíritu', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                Text('navideño 🎄', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
              ])),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/images/frostfit_logo.png', width: 58, height: 58, fit: BoxFit.cover),
              ),
            ]),
            const SizedBox(height: 22),
            _heroCard(),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _metric('PASOS', '$_steps', Icons.directions_walk, 'Objetivo: ${frostProfile.stepGoal}')),
              const SizedBox(width: 12),
              Expanded(child: _metric('DISTANCIA', '${(_distance / 1000).toStringAsFixed(2)} km', Icons.route, 'GPS / pasos estimados')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _metric('TIEMPO', _time(), Icons.timer_outlined, 'Sesión actual')),
              const SizedBox(width: 12),
              Expanded(child: _metric('RITMO', _movement, Icons.bolt, 'Acelerómetro')),
            ]),
            const SizedBox(height: 12),
            CaloriesCard(profile: frostProfile, steps: _steps),
            const SizedBox(height: 22),
            _sectionTitle('Sensores en vivo', 'DATOS DEL DISPOSITIVO'),
            const SizedBox(height: 10),
            _sensorCard('Acelerómetro · m/s²', 'X ${_ax.toStringAsFixed(2)}   Y ${_ay.toStringAsFixed(2)}   Z ${_az.toStringAsFixed(2)}', Icons.speed),
            const SizedBox(height: 9),
            _sensorCard('Giroscopio · rad/s', 'X ${_gx.toStringAsFixed(2)}   Y ${_gy.toStringAsFixed(2)}   Z ${_gz.toStringAsFixed(2)}', Icons.screen_rotation_alt),
            const SizedBox(height: 9),
            _sensorCard('Orientación relativa', 'Inclinación X ${(_roll * 180 / math.pi).toStringAsFixed(1)}°  ·  Y ${(_pitch * 180 / math.pi).toStringAsFixed(1)}°', Icons.screen_rotation),
            const SizedBox(height: 9),
            _sensorCard('Velocidad GPS', '${_speedKmh.toStringAsFixed(1)} km/h', Icons.speed),
            const SizedBox(height: 22),
            _sectionTitle('Tu recorrido', 'GPS EN TIEMPO REAL'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(height: 220, child: FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.fitness_christmas',
                  ),
                  if (_route.isNotEmpty)
                    PolylineLayer(polylines: [Polyline(points: _route, strokeWidth: 4, color: AppTheme.red)]),
                  if (_position != null)
                    MarkerLayer(markers: [Marker(
                      point: center, width: 42, height: 42,
                      child: const Icon(Icons.location_on, color: AppTheme.red, size: 38),
                    )]),
                ],
              )),
            ),
            const SizedBox(height: 8),
            Text(_position == null ? 'El mapa mostrará tu ubicación al iniciar.' :
            'GPS: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            const SizedBox(height: 18),
            if (!_availableSteps) const Text('Este dispositivo no reporta el sensor de pasos; revisa la compatibilidad.', style: TextStyle(color: AppTheme.gold)),
            _controls(),
            const SizedBox(height: 12),
            const Center(child: Text('Muévete, disfruta y comparte la energía ✨', style: TextStyle(color: AppTheme.muted, fontSize: 12))),
          ])),
        ),
      ])),
      const Positioned.fill(child: SnowFall()),
    ]);
  }

  Widget _heroCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(colors: [Color(0xFF1C5944), Color(0xFF12372C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      border: Border.all(color: AppTheme.mint.withOpacity(.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: const [Icon(Icons.ac_unit, color: AppTheme.mint, size: 17), SizedBox(width: 7), Text('RETO DE TEMPORADA', style: TextStyle(color: AppTheme.mint, fontWeight: FontWeight.bold, letterSpacing: 1))]),
      const SizedBox(height: 13),
      const Text('Cada paso cuenta.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(_running ? (_paused ? 'Entrenamiento en pausa' : 'Tu sesión está activa') : '¿Listo para superar tu marca?', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 16),
      ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(
        value: (_steps / frostProfile.stepGoal).clamp(0, 1), minHeight: 8,
        backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(AppTheme.mint),
      )),
      const SizedBox(height: 8),
      Text('${(_steps / frostProfile.stepGoal * 100).clamp(0, 100).toStringAsFixed(0)}% del objetivo diario', style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]),
  );

  Widget _metric(String title, String value, IconData icon, String foot) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppTheme.gold, size: 20),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: AppTheme.muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 5),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(foot, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 10)),
      ]),
    ),
  );

  Widget _sectionTitle(String title, String tag) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    Text(tag, style: const TextStyle(fontSize: 9, color: AppTheme.mint, letterSpacing: .8, fontWeight: FontWeight.bold)),
  ]);

  Widget _sensorCard(String title, String value, IconData icon) => Container(
    width: double.infinity, padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(17)),
    child: Row(children: [
      Icon(icon, color: AppTheme.mint), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4), Text(value, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
      ])),
    ]),
  );

  Widget _controls() => Row(children: [
    Expanded(child: ElevatedButton.icon(
      onPressed: _running ? _togglePause : _startWorkout,
      icon: Icon(_running && !_paused ? Icons.pause_rounded : Icons.play_arrow_rounded),
      label: Text(!_running ? 'INICIAR' : _paused ? 'CONTINUAR' : 'PAUSAR'),
      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mint, foregroundColor: AppTheme.forest, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    )),
    if (_running) ...[
      const SizedBox(width: 10),
      IconButton.filled(
        onPressed: _finishWorkout, icon: const Icon(Icons.stop_rounded),
        style: IconButton.styleFrom(backgroundColor: AppTheme.red, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
      ),
    ],
  ]);
}