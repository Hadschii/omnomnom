import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_state.dart';
import '../models/recipe.dart';
import '../theme/recipe_accents.dart';

/// Hands-free cook-along: one big step at a time, a live per-step timer, and a
/// grouped ingredient list that surfaces the current step's group as "needed
/// now" while the rest stay greyed below. Each ingredient is shown once and can
/// be ticked off.
class CookScreen extends StatefulWidget {
  final String recipeId;
  const CookScreen({super.key, required this.recipeId});

  @override
  State<CookScreen> createState() => _CookScreenState();
}

class _CookScreenState extends State<CookScreen> {
  int _step = 0;
  final _checked = <int>{}; // indices into recipe.ingredients

  Timer? _ticker;
  int? _remaining; // seconds left on the current step's timer
  bool _running = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _goTo(int index, int lastIndex) {
    if (index < 0 || index > lastIndex) return;
    _resetTimer();
    setState(() => _step = index);
  }

  void _resetTimer() {
    _ticker?.cancel();
    _ticker = null;
    _remaining = null;
    _running = false;
  }

  void _toggleTimer(int seconds) {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
      return;
    }
    _remaining ??= seconds;
    if (_remaining! <= 0) _remaining = seconds;
    setState(() => _running = true);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining == null || _remaining! <= 0) {
        t.cancel();
        setState(() {
          _running = false;
          _remaining = 0;
        });
        return;
      }
      setState(() => _remaining = _remaining! - 1);
    });
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/recipe/${widget.recipeId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecipeBloc, RecipeState>(
      builder: (context, state) {
        Recipe? recipe;
        if (state is RecipeLoaded) {
          for (final r in state.recipes) {
            if (r.id == widget.recipeId) {
              recipe = r;
              break;
            }
          }
        }
        if (recipe == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final accent = accentForRecipe(recipe);
        final steps = recipe.instructions;
        if (steps.isEmpty) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _topBar(recipe.title, accent),
                  const Expanded(
                    child: Center(child: Text('This recipe has no steps yet.')),
                  ),
                ],
              ),
            ),
          );
        }

        if (_step >= steps.length) _step = steps.length - 1;
        final last = steps.length - 1;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _topBar(recipe.title, accent),
                _progress(steps.length, accent),
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: _stepContent(recipe, accent, last),
                  ),
                ),
                _ingredientPanel(recipe, accent),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Top bar & progress -------------------------------------------------

  Widget _topBar(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _close,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                  color: Color(0xFFF1F1F4), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 18, color: Color(0xFF3A3A3C)),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: metaGrey),
            ),
          ),
          GestureDetector(
            // PLACEHOLDER: "keep screen awake" while cooking needs a wakelock
            // plugin; stubbed for now.
            onTap: () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                  content: Text('Keep screen awake — coming soon'))),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(Icons.light_mode_outlined, size: 18, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress(int count, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 5,
                decoration: BoxDecoration(
                  color: i <= _step ? accent : const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Step content -------------------------------------------------------

  Widget _stepContent(Recipe recipe, Color accent, int last) {
    final step = recipe.instructions[_step];
    final groups = step.effectiveGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_step > 0)
              _navButton(Icons.chevron_left, accent,
                  filled: false, onTap: () => _goTo(_step - 1, last))
            else
              const SizedBox(width: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    'STEP ${_step + 1} OF ${last + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.6,
                    ),
                  ),
                  for (final g in groups)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: groupColor(g).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        g.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: groupColor(g),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _navButton(
              _step == last ? Icons.check : Icons.chevron_right,
              accent,
              filled: true,
              onTap: () => _step == last ? _close() : _goTo(_step + 1, last),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          step.description,
          style: const TextStyle(
              fontSize: 25, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3),
        ),
        // Optional step photo — only shown when the step has one.
        if (step.photoPath != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(step.photoPath!),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
        if (step.timerSeconds != null) ...[
          const SizedBox(height: 16),
          _timerControl(step.timerSeconds!, accent),
        ],
      ],
    );
  }

  Widget _navButton(IconData icon, Color accent,
      {required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: filled ? accent : const Color(0xFFF1F1F4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 22, color: filled ? Colors.white : const Color(0xFF3A3A3C)),
      ),
    );
  }

  Widget _timerControl(int seconds, Color accent) {
    final showing = _remaining ?? seconds;
    final done = _remaining == 0;
    final label = done
        ? 'Timer done'
        : _running
            ? 'Tap to pause · ${formatTimer(showing)}'
            : (_remaining == null
                ? 'Tap to start ${formatTimer(seconds)}'
                : 'Tap to resume · ${formatTimer(showing)}');
    return GestureDetector(
      onTap: () => _toggleTimer(seconds),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: done ? accent.withValues(alpha: 0.12) : const Color(0xFFF1F1F4),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done
                  ? Icons.check_circle
                  : (_running ? Icons.pause_circle : Icons.timer_outlined),
              size: 18,
              color: accent,
            ),
            const SizedBox(width: 9),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A3A3C)),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Ingredient panel ---------------------------------------------------

  Widget _ingredientPanel(Recipe recipe, Color accent) {
    // Group ingredient indices by group, preserving first-seen order.
    final byGroup = <String?, List<int>>{};
    for (var i = 0; i < recipe.ingredients.length; i++) {
      byGroup.putIfAbsent(recipe.ingredients[i].group, () => []).add(i);
    }
    final active = recipe.instructions[_step].effectiveGroups;

    // Active groups first (needed now), then the rest in natural order.
    final orderedKeys = <String?>[
      ...active.where(byGroup.containsKey),
      ...byGroup.keys.where((k) => !active.contains(k)),
    ];

    final sections = <Widget>[];
    for (final key in orderedKeys) {
      final isActive = key != null && active.contains(key);
      sections.add(_groupHeader(recipe, key, isActive, accent));
      for (final idx in byGroup[key]!) {
        sections.add(_ingredientRow(recipe, idx, isActive, accent));
      }
      sections.add(const SizedBox(height: 14));
    }

    return Expanded(
      flex: 4,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFAF9F8),
          border: Border(top: BorderSide(color: Color(0xFFECECEF))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('All ingredients',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  Text('BY COMPONENT',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9B9B9B),
                          letterSpacing: 0.6)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                children: sections,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupHeader(Recipe recipe, String? key, bool isActive, Color accent) {
    final String text;
    final Color color;
    if (key == null) {
      text = 'OTHER';
      color = isActive ? accent : const Color(0xFF9B9B9B);
    } else if (isActive) {
      text = '${key.toUpperCase()} · NEEDED NOW';
      color = accent;
    } else {
      // Where this group is first used, to hint when it'll matter.
      var firstStep = -1;
      for (var i = 0; i < recipe.instructions.length; i++) {
        if (recipe.instructions[i].effectiveGroups.contains(key)) {
          firstStep = i;
          break;
        }
      }
      text = firstStep >= 0
          ? '${key.toUpperCase()} · FROM STEP ${firstStep + 1}'
          : key.toUpperCase();
      color = const Color(0xFF9B9B9B);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? (key == null ? accent : groupColor(key))
                  : const Color(0xFFC7C7CC),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ingredientRow(Recipe recipe, int idx, bool isActive, Color accent) {
    final ing = recipe.ingredients[idx];
    final checked = _checked.contains(idx);
    return Opacity(
      opacity: isActive ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          if (checked) {
            _checked.remove(idx);
          } else {
            _checked.add(idx);
          }
        }),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: checked ? accent : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: checked
                      ? null
                      : Border.all(
                          color: isActive
                              ? accent.withValues(alpha: 0.5)
                              : const Color(0xFFD2D2D6),
                          width: 2),
                ),
                child: checked
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  ing.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: checked ? metaGrey : null,
                  ),
                ),
              ),
              if (ing.amount.isNotEmpty)
                Text(
                  ing.amount,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: checked
                        ? metaGrey
                        : (isActive ? accent : const Color(0xFF3A3A3C)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
