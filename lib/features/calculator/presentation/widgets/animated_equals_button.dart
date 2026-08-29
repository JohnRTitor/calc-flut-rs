import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';

/// A specialized button widget for the equals sign in the calculator.
///
/// It provides visual feedback by flashing red and shaking horizontally if the
/// evaluation of the current expression fails (e.g., due to a syntax error).
class AnimatedEqualsButton extends ConsumerStatefulWidget {
  /// The callback to evaluate the expression. Must return true if successful, false otherwise.
  final Future<bool> Function() onEvaluate;

  const AnimatedEqualsButton({super.key, required this.onEvaluate});

  @override
  ConsumerState<AnimatedEqualsButton> createState() =>
      _AnimatedEqualsButtonState();
}

class _AnimatedEqualsButtonState extends ConsumerState<AnimatedEqualsButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colorScheme = Theme.of(context).colorScheme;
    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
          begin: colorScheme.primaryContainer,
          end: colorScheme.error,
        ),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: colorScheme.error,
          end: colorScheme.primaryContainer,
        ),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handlePress() async {
    if (_controller.isAnimating) return;
    final success = await widget.onEvaluate();
    if (!success && mounted) {
      HapticFeedback.vibrate();
      _controller.forward(from: 0.0);
    }
  }

  void _handlePressDown() {
    setState(() => _scale = 0.94);
  }

  void _handlePressUp() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final uiStyle = ref.watch(uiStyleProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (uiStyle == UiStyle.liquidGlass) {
      return _buildGlassVariant(colorScheme);
    }
    return _buildMaterialVariant(colorScheme);
  }

  Widget _buildMaterialVariant(ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Padding(
              padding: const EdgeInsets.all(3.0),
              child: AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: SizedBox.expand(
                  child: GestureDetector(
                    onTapDown: (_) => _handlePressDown(),
                    onTapUp: (_) => _handlePressUp(),
                    onTapCancel: () => _handlePressUp(),
                    child: Tooltip(
                      message: 'Calculate',
                      waitDuration: const Duration(milliseconds: 400),
                      child: FilledButton(
                        onPressed: _handlePress,
                        style: FilledButton.styleFrom(
                          backgroundColor: _controller.isAnimating
                              ? _colorAnimation.value
                              : colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '=',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .animate(controller: _controller, autoPlay: false)
            .shakeX(hz: 4, amount: 4);
      },
    );
  }

  Widget _buildGlassVariant(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: SizedBox.expand(
          child: GestureDetector(
            onTapDown: (_) => _handlePressDown(),
            onTapUp: (_) => _handlePressUp(),
            onTapCancel: () => _handlePressUp(),
            child: SharedSurface(
              uiStyle: UiStyle.liquidGlass,
              onTap: _handlePress,
              isInteractive: true,
              isSelected: true,
              glassRole: GlassSurfaceRole.primary,
              borderRadius: BorderRadius.circular(28),
              child: Center(
                child: Text(
                  '=',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
