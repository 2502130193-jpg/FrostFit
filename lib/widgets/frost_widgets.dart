import 'dart:math';
import 'package:flutter/material.dart';
import '../models/frost_profile.dart';

const kBg = Color(0xFF0B1F1A);
const kCard = Color(0xFF163329);
const kMint = Color(0xFFB9F5D0);
const kGold = Color(0xFFE8C872);
const kRed = Color(0xFFE53935);

/// Nieve cayendo. Úsala dentro de un Stack encima de tu pantalla.
class SnowFall extends StatefulWidget {
  final int count;
  const SnowFall({super.key, this.count = 40});
  @override
  State<SnowFall> createState() => _SnowFallState();
}

class _Flake {
  static final _r = Random();
  final x = _r.nextDouble();
  final y = _r.nextDouble();
  final size = 1 + _r.nextDouble() * 2.5;
  final speed = 1 + _r.nextInt(2); // entero = loop sin saltos
  final phase = _r.nextDouble() * 6.28;
}

class _SnowFallState extends State<SnowFall>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 14))
    ..repeat();
  late final _flakes = List.generate(widget.count, (_) => _Flake());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
          painter: _SnowPainter(_flakes, _c.value), size: Size.infinite),
    ),
  );
}

class _SnowPainter extends CustomPainter {
  final List<_Flake> flakes;
  final double t;
  _SnowPainter(this.flakes, this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white.withOpacity(.75);
    for (final f in flakes) {
      final y = (f.y + t * f.speed) % 1;
      final x = f.x + sin(t * 12.56 + f.phase) * .02;
      canvas.drawCircle(Offset(x * s.width, y * s.height), f.size, p);
    }
  }

  @override
  bool shouldRepaint(_SnowPainter old) => true;
}

/// Anillo de progreso animado (rojo → dorado → menta).
class ActivityRing extends StatelessWidget {
  final double progress, size;
  final Widget child;
  const ActivityRing(
      {super.key, required this.progress, this.size = 150, required this.child});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
    duration: const Duration(milliseconds: 1000),
    curve: Curves.easeOutCubic,
    builder: (_, v, __) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RingPainter(v), child: Center(child: child)),
    ),
  );
}

class _RingPainter extends CustomPainter {
  final double v;
  _RingPainter(this.v);
  @override
  void paint(Canvas canvas, Size s) {
    const w = 14.0;
    final rect = Rect.fromLTWH(w / 2, w / 2, s.width - w, s.height - w);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = Colors.white12;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [kRed, kGold, kMint],
        transform: GradientRotation(-pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, 0, 2 * pi, false, track);
    canvas.drawArc(rect, -pi / 2, 2 * pi * v, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v;
}

/// Corazón que late.
class PulseHeart extends StatefulWidget {
  const PulseHeart({super.key});
  @override
  State<PulseHeart> createState() => _PulseHeartState();
}

class _PulseHeartState extends State<PulseHeart>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(begin: .85, end: 1.15)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: const Icon(Icons.favorite, color: kRed, size: 22),
  );
}

class MiniStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const MiniStat(this.icon, this.value, this.label, {super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: kGold, size: 20),
    const SizedBox(height: 4),
    Text(value,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
  ]);
}

/// Tarjeta de calorías para tu pantalla de Inicio.
class CaloriesCard extends StatelessWidget {
  final FrostProfile profile;
  final int steps;
  const CaloriesCard({super.key, required this.profile, required this.steps});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: profile,
    builder: (_, __) {
      final kcal = profile.calories(steps);
      final cookies = (kcal / 50).toStringAsFixed(1); // 1 galleta ≈ 50 kcal
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kMint.withOpacity(.25)),
        ),
        child: Column(children: [
          Row(children: const [
            PulseHeart(),
            SizedBox(width: 8),
            Text('CALORÍAS QUEMADAS',
                style: TextStyle(
                    color: kMint, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ]),
          const SizedBox(height: 16),
          ActivityRing(
            progress: kcal / profile.calorieGoal,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(kcal.toStringAsFixed(0),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900)),
              const Text('kcal', style: TextStyle(color: Colors.white60)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            MiniStat(Icons.route, profile.distanceKm(steps).toStringAsFixed(2),
                'km'),
            MiniStat(Icons.timer, '${profile.activeMinutes(steps)}', 'min activos'),
            MiniStat(Icons.local_fire_department,
                profile.calorieGoal.toStringAsFixed(0), 'meta kcal'),
          ]),
          const SizedBox(height: 14),
          Text('🍪 Equivale a $cookies galletas navideñas quemadas',
              style: const TextStyle(color: kGold, fontSize: 13)),
        ]),
      );
    },
  );
}