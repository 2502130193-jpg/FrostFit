import 'package:flutter/material.dart';
import '../models/frost_profile.dart';
import '../services/auth_service.dart';
import '../widgets/frost_widgets.dart';

/// Se muestra en la pestaña Perfil cuando la huella ya validó.
class FrostProfileScreen extends StatefulWidget {
  final FrostProfile profile;
  const FrostProfileScreen({super.key, required this.profile});
  @override
  State<FrostProfileScreen> createState() => _FrostProfileScreenState();
}

class _FrostProfileScreenState extends State<FrostProfileScreen> {
  FrostProfile get p => widget.profile;
  late final _name = TextEditingController(text: p.name);
  late final _age = TextEditingController(text: '${p.age}');
  late final _weight = TextEditingController(text: '${p.weightKg}');
  late final _height = TextEditingController(text: '${p.heightCm}');
  late bool _male = p.isMale;
  late double _goal = p.stepGoal.toDouble();
  late int _avatar = p.avatar;

  @override
  void initState() {
    super.initState();
    p.addListener(_sync); // se actualiza sola al cambiar de perfil
  }

  @override
  void dispose() {
    p.removeListener(_sync);
    _name.dispose();
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    setState(() {
      _name.text = p.name;
      _age.text = '${p.age}';
      _weight.text = '${p.weightKg}';
      _height.text = '${p.heightCm}';
      _male = p.isMale;
      _goal = p.stepGoal.toDouble();
      _avatar = p.avatar;
    });
  }

  Future<void> _pickAvatar() async {
    final i = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: kCard,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(spacing: 16, runSpacing: 16, children: [
          for (var i = 0; i < FrostProfile.avatars.length; i++)
            GestureDetector(
              onTap: () => Navigator.pop(context, i),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: i == _avatar ? kRed : kBg,
                child: Text(FrostProfile.avatars[i],
                    style: const TextStyle(fontSize: 34)),
              ),
            ),
        ]),
      ),
    );
    if (i != null) setState(() => _avatar = i);
  }

  Future<void> _switchProfile() async {
    final newName = TextEditingController();
    // El panel solo devuelve la decisión; el cambio se hace cuando ya cerró.
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Quién entrena hoy?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final u in auth.users)
              ListTile(
                leading: Icon(
                    u == auth.user ? Icons.check_circle : Icons.person_outline,
                    color: kMint),
                title: Text(u),
                onTap: () => Navigator.pop(ctx, 'u:$u'),
              ),
            const Divider(color: Colors.white24),
            TextField(
              controller: newName,
              decoration: const InputDecoration(labelText: 'Nuevo perfil'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, 'n:${newName.text}'),
                style: FilledButton.styleFrom(
                    backgroundColor: kMint, foregroundColor: kBg),
                icon: const Icon(Icons.add),
                label: const Text('CREAR PERFIL'),
              ),
            ),
          ],
        ),
      ),
    );

    // Espera a que termine la animación de cierre del panel.
    await Future.delayed(const Duration(milliseconds: 350));
    newName.dispose();
    if (result == null || !mounted) return;

    final value = result.substring(2);
    if (result.startsWith('u:')) {
      await auth.switchTo(value);
    } else {
      final err = await auth.create(value);
      if (err != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  Future<void> _save() async {
    p
      ..name = _name.text.trim().isEmpty ? p.name : _name.text.trim()
      ..age = (int.tryParse(_age.text) ?? p.age).clamp(10, 100)
      ..weightKg = (double.tryParse(_weight.text) ?? p.weightKg).clamp(30.0, 250.0)
      ..heightCm = (double.tryParse(_height.text) ?? p.heightCm).clamp(120.0, 230.0)
      ..isMale = _male
      ..stepGoal = _goal.round()
      ..avatar = _avatar;
    await p.save();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Perfil guardado 🎄')));
  }

  Widget _field(String label, TextEditingController c,
      {String? suffix, bool num = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType:
          num ? const TextInputType.numberWithOptions(decimal: true) : null,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            labelStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: kCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Stack(children: [
    ListView(padding: const EdgeInsets.fromLTRB(20, 56, 20, 24), children: [
      const Text('Mi perfil',
          style: TextStyle(
              color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 24),
      Center(
        child: GestureDetector(
          onTap: _pickAvatar,
          child: Stack(alignment: Alignment.bottomRight, children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [kRed, kMint, kGold, kRed]),
              ),
              child: CircleAvatar(
                radius: 54,
                backgroundColor: kCard,
                child: Text(FrostProfile.avatars[_avatar],
                    style: const TextStyle(fontSize: 56)),
              ),
            ),
            const CircleAvatar(
                radius: 16,
                backgroundColor: kMint,
                child: Icon(Icons.edit, size: 16, color: kBg)),
          ]),
        ),
      ),
      const SizedBox(height: 28),
      _field('Nombre', _name, num: false),
      Row(children: [
        Expanded(child: _field('Edad', _age, suffix: 'años')),
        const SizedBox(width: 12),
        Expanded(child: _field('Peso', _weight, suffix: 'kg')),
      ]),
      _field('Estatura', _height, suffix: 'cm'),
      Row(children: [
        for (final m in [true, false])
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(m ? 'Hombre' : 'Mujer'),
              selected: _male == m,
              selectedColor: kMint,
              onSelected: (_) => setState(() => _male = m),
            ),
          ),
      ]),
      const SizedBox(height: 16),
      Text('Meta diaria: ${_goal.round()} pasos',
          style: const TextStyle(color: kGold, fontWeight: FontWeight.w700)),
      Slider(
        value: _goal,
        min: 3000,
        max: 20000,
        divisions: 34,
        activeColor: kRed,
        onChanged: (v) => setState(() => _goal = v),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _save,
        style: FilledButton.styleFrom(
            backgroundColor: kMint,
            foregroundColor: kBg,
            padding: const EdgeInsets.symmetric(vertical: 16)),
        icon: const Icon(Icons.check),
        label: const Text('GUARDAR CAMBIOS'),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: kCard, borderRadius: BorderRadius.circular(24)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          MiniStat(Icons.monitor_weight, p.bmi.toStringAsFixed(1),
              'IMC · ${p.bmiLabel}'),
          MiniStat(Icons.bolt, p.bmr.toStringAsFixed(0), 'kcal en reposo'),
          MiniStat(Icons.water_drop,
              '${(p.waterMl / 1000).toStringAsFixed(1)} L', 'agua al día'),
        ]),
      ),
      const SizedBox(height: 24),
      Center(
          child: Text('Perfil activo: ${auth.user}',
              style: const TextStyle(color: Colors.white60))),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _switchProfile,
        style: OutlinedButton.styleFrom(
            foregroundColor: kMint, side: const BorderSide(color: kMint)),
        icon: const Icon(Icons.swap_horiz),
        label: const Text('CAMBIAR PERFIL'),
      ),
      const SizedBox(height: 16),
      const Center(
          child: Text('FrostFit · Tu progreso, tu ritmo 🎄',
              style: TextStyle(color: kGold))),
    ]),
    const Positioned.fill(child: SnowFall()),
  ]);
}