import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/display_panel.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/keypad.dart';
import 'package:calc_flut_rs/shared/layouts/responsive_workspace_layout.dart';

import 'package:calc_flut_rs/features/calculator/presentation/screens/function_evaluator_screen.dart';
import 'package:calc_flut_rs/features/history/presentation/screens/history_screen.dart';
import 'package:calc_flut_rs/features/history/presentation/widgets/recent_history_panel.dart';
import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/app/navigation/route_transitions.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/pill_switcher.dart';

/// The main screen for the calculator functionality.
///
/// Lays out the display panel at the top and the keypad filling the rest of the vertical space.
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void update(int index) {
    state = index;
  }
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(
  SelectedTabNotifier.new,
);

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  @override
  Widget build(BuildContext context) {
    final uiStyle = ref.watch(uiStyleProvider);
    final isGlass = uiStyle == UiStyle.liquidGlass;
    final selectedTabIndex = ref.watch(selectedTabProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 4.0,
          ).copyWith(top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHistoryButton(context, isGlass, uiStyle, selectedTabIndex),
              const SizedBox(width: 8),
              Flexible(child: _buildSegmentedToggle(uiStyle, selectedTabIndex)),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: context.motion(const Duration(milliseconds: 300)),
            child: selectedTabIndex == 0
                ? const _ScientificLayout()
                : const FunctionEvaluatorScreen(),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedToggle(UiStyle uiStyle, int selectedTabIndex) {
    return PillSwitcher(
      uiStyle: uiStyle,
      label1: 'Calculator',
      label2: 'Fn Evaluator',
      tooltip1: 'Standard calculator for basic arithmetic',
      tooltip2: 'Function evaluator with variables',
      isFirstSelected: selectedTabIndex == 0,
      onChanged: (isCalculatorSelected) {
        ref
            .read(selectedTabProvider.notifier)
            .update(isCalculatorSelected ? 0 : 1);
      },
    );
  }

  Widget _buildHistoryButton(
    BuildContext context,
    bool isGlass,
    UiStyle uiStyle,
    int selectedTabIndex,
  ) {
    final theme = Theme.of(context);
    final glassCard = resolveGlassStyle(
      theme.colorScheme,
      brightness: theme.brightness,
      role: GlassSurfaceRole.card,
    );

    void onPressed() async {
      final initialCategory = selectedTabIndex == 1
          ? HistoryCategory.functionEvaluator
          : HistoryCategory.calculator;

      final result = await Navigator.push<HistoryCategory>(
        context,
        FadePageRoute(page: HistoryScreen(initialCategory: initialCategory)),
      );

      if (result != null) {
        final nextIndex = result == HistoryCategory.functionEvaluator ? 1 : 0;
        if (nextIndex != selectedTabIndex) {
          ref.read(selectedTabProvider.notifier).update(nextIndex);
        }
      }
    }

    return isGlass
        ? SharedSurface(
            uiStyle: uiStyle,
            glassRole: GlassSurfaceRole.button,
            frosted: true,
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.history, size: 20),
                onPressed: onPressed,
                tooltip: 'History',
                color: glassCard.foregroundColor,
              ),
            ),
          )
        : SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.history, size: 20),
              onPressed: onPressed,
              tooltip: 'History',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
  }
}

class _ScientificLayout extends ConsumerWidget {
  const _ScientificLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveWorkspaceLayout(
      // Pinned, because a numeric keypad is a fixed instrument: the keys have to
      // stay under the same thumb, so the display area is what gives way.
      pinControls: true,
      controlsMinHeight: 450,
      controls: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [Expanded(child: Keypad())],
      ),
      displayArea: const DisplayPanel(),
      // On a desktop-class window, this tool's own recent results beside it.
      // Everywhere else the width is worth more to the keys than to a list.
      sidePanel: RecentHistoryPanel(category: HistoryCategory.calculator),
    );
  }
}
