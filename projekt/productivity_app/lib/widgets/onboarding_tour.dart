import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';

/// One slide of the first-run guide. The five steps double as the product
/// pitch / talking points for a live demo of the app.
class _Step {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  const _Step(this.icon, this.accent, this.title, this.body);
}

const List<_Step> _steps = [
  _Step(Icons.bolt_rounded, AppColors.neonGreen, Strings.onboarding1Title,
      Strings.onboarding1Body),
  _Step(Icons.event_note_rounded, AppColors.taskDaily, Strings.onboarding2Title,
      Strings.onboarding2Body),
  _Step(Icons.verified_rounded, AppColors.neonCyan, Strings.onboarding3Title,
      Strings.onboarding3Body),
  _Step(Icons.leaderboard_rounded, AppColors.neonYellow,
      Strings.onboarding4Title, Strings.onboarding4Body),
  _Step(Icons.emoji_events_rounded, AppColors.neonPink, Strings.onboarding5Title,
      Strings.onboarding5Body),
];

const _prefKey = 'seen_onboarding_v1';

/// True once the user has seen (or skipped) the first-run guide.
Future<bool> onboardingSeen() async {
  final p = await SharedPreferences.getInstance();
  return p.getBool(_prefKey) ?? false;
}

/// Marks the guide as seen so it doesn't auto-open on the next launch.
Future<void> markOnboardingSeen() async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_prefKey, true);
}

/// Shows the guide as a centered neo dialog. Used on first run (calendar) and
/// on demand from Settings ("Jak to funguje").
Future<void> showOnboardingTour(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _OnboardingDialog(),
  );
}

class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog();

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final size = MediaQuery.of(context).size;
    final width = size.width < 460 ? size.width - 32 : 420.0;
    final accent = _steps[_index].accent;
    final isLast = _index == _steps.length - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(NeoTheme.spaceMd),
      child: Container(
        width: width,
        decoration: NeoTheme.cardDecoration(isDark: isDark, borderColor: accent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(Strings.onboardingSkip),
              ),
            ),
            SizedBox(
              height: 320,
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) =>
                    _StepView(step: _steps[i], isDark: isDark),
              ),
            ),
            const SizedBox(height: NeoTheme.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? accent
                        : (isDark
                            ? AppColors.borderSubtle
                            : AppColors.borderBold),
                    borderRadius: BorderRadius.circular(NeoTheme.radiusSmall),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(NeoTheme.spaceMd),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _next,
                  child: Text(
                    isLast ? Strings.onboardingDone : Strings.onboardingNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  final _Step step;
  final bool isDark;
  const _StepView({required this.step, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NeoTheme.spaceLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: step.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
              border: Border.all(color: step.accent, width: NeoTheme.borderWidth),
              boxShadow: [
                BoxShadow(
                  color: step.accent.withValues(alpha: 0.35),
                  offset: NeoTheme.shadowOffset,
                  blurRadius: 0,
                ),
              ],
            ),
            child: Icon(step.icon, size: 44, color: step.accent),
          ),
          const SizedBox(height: NeoTheme.spaceLg),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: NeoTheme.headline.copyWith(letterSpacing: 1.0, color: step.accent),
          ),
          const SizedBox(height: NeoTheme.spaceSm),
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: NeoTheme.body.copyWith(
              color: isDark ? AppColors.textSecondary : Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
