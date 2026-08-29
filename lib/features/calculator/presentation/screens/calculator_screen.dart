import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/display_panel.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/keypad.dart';
import 'package:calc_flut_rs/shared/layouts/responsive_keypad_layout.dart';

import 'package:calc_flut_rs/features/calculator/presentation/screens/function_evaluator_screen.dart';
import 'package:calc_flut_rs/features/history/presentation/screens/history_screen.dart';
import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/app/navigation/route_transitions.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/screens/modular_arithmetic_workspace_screen.dart';
import 'package:calc_flut_rs/shared/widgets/multi_pill_switcher.dart';

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
            duration: const Duration(milliseconds: 300),
            child: selectedTabIndex == 0
                ? const _ScientificLayout()
                : selectedTabIndex == 1
                ? const FunctionEvaluatorScreen()
                : const ModularArithmeticWorkspaceScreen(),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedToggle(UiStyle uiStyle, int selectedTabIndex) {
    return MultiPillSwitcher(
      uiStyle: uiStyle,
      labels: const ['Calculator', 'Fn Evaluator', 'Mod'],
      tooltips: const [
        'Standard calculator for basic arithmetic',
        'Function evaluator with variables',
        'Modular arithmetic workspace'
      ],
      selectedIndex: selectedTabIndex,
      onChanged: (index) {
        ref.read(selectedTabProvider.notifier).update(index);
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
          : selectedTabIndex == 2
              ? HistoryCategory.modularArithmetic
              : HistoryCategory.calculator;

      final result = await Navigator.push<HistoryCategory>(
        context,
        FadePageRoute(
          page: HistoryScreen(initialCategory: initialCategory),
        ),
      );
      
      if (result != null) {
        int nextIndex = 0;
        if (result == HistoryCategory.functionEvaluator) nextIndex = 1;
        if (result == HistoryCategory.modularArithmetic) nextIndex = 2;
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

class _ScientificLayout extends StatelessWidget {
  const _ScientificLayout();

  @override
  Widget build(BuildContext context) {
    return const ResponsiveKeypadLayout(
      displayArea: DisplayPanel(),
      keypad: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Expanded(child: Keypad())],
      ),
      keypadMinHeight: 450,
    );
  }
}
