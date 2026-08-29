import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/token_text_field.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The main display area of the calculator.
///
/// Shows the current mathematical expression, real-time evaluation preview,
/// error messages, and the final evaluated result. Adapts its background to the
/// current UI style (Material vs Liquid Glass).
class DisplayPanel extends ConsumerWidget {
  const DisplayPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorProvider);
    final uiStyle = ref.watch(uiStyleProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget slideFadeTransition(Widget child, Animation<double> animation) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0.0, 0.3),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      );
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expression input
        Align(
          alignment: Alignment.bottomRight,
          child: const TokenTextField()
              .animate(key: ValueKey(state.expression))
              .scaleXY(
                begin: 1.02,
                end: 1.0,
                duration: 150.ms,
                curve: Curves.easeOut,
              ),
        ),
        const SizedBox(height: 8),

        // Bottom Area: Error, Preview, or Main Result
        SizedBox(
          height: 64,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: slideFadeTransition,
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.bottomRight,
                    children: <Widget>[...previousChildren, ?currentChild],
                  );
                },
            child: () {
              if (state.error != null) {
                return Text(
                  state.error!,
                  key: ValueKey('error_${state.error}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              } else if (!state.showResult && state.preview.isNotEmpty) {
                return Container(
                  key: ValueKey('preview_${state.preview}'),
                  height: 64,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '= ${state.preview}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                );
              } else if (state.showResult) {
                return GestureDetector(
                  key: const ValueKey('main_result_container'),
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: state.result));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Result copied'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(milliseconds: 1500),
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: slideFadeTransition,
                      child: Text(
                        state.displayAsFraction && state.exactResult != null
                            ? state.exactResult!
                            : (state.result.isEmpty ? '0' : state.result),
                        key: ValueKey(
                          'result_${state.result}_${state.exactResult}',
                        ),
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          fontSize: 48,
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return const SizedBox.shrink(key: ValueKey('empty_result'));
              }
            }(),
          ),
        ),
      ],
    );

    if (uiStyle == UiStyle.liquidGlass) {
      return RepaintBoundary(
        child: SharedSurface(
          uiStyle: uiStyle,
          glassRole: GlassSurfaceRole.panel,
          frosted: true,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          borderRadius: BorderRadius.circular(24),
          child: content,
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: content,
      ),
    );
  }
}
