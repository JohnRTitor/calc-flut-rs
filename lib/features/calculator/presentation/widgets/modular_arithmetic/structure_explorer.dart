import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/modular_arithmetic_workspace_provider.dart';
import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/widgets/recent_history_panel.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/modular_arithmetic_workspace_state.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/layouts/responsive_workspace_layout.dart';
import 'package:calc_flut_rs/shared/widgets/app_dropdown_menu.dart';
import 'package:calc_flut_rs/shared/widgets/app_button.dart';

import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_context_card.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_arithmetic_explorer_empty_state.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_arithmetic_analysis_grid.dart';

class StructureExplorer extends ConsumerStatefulWidget {
  const StructureExplorer({super.key});

  @override
  ConsumerState<StructureExplorer> createState() => _StructureExplorerState();
}

class _StructureExplorerState extends ConsumerState<StructureExplorer> {
  late TextEditingController _nController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(modularArithmeticWorkspaceProvider);
    _nController = TextEditingController(text: state.explorerN);
  }

  @override
  void dispose() {
    _nController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modularArithmeticWorkspaceProvider);
    final uiStyle = ref.watch(uiStyleProvider);

    String currentLabel;
    switch (state.explorerType) {
      case 'ring':
        currentLabel = 'Z_n (Ring)';
        break;
      case 'group':
        currentLabel = 'Z_n* (Group)';
        break;
      case 'field':
        currentLabel = 'GF(p) (Field)';
        break;
      default:
        currentLabel = 'Z_n (Ring)';
    }

    final typeEntries = [
      AppDropdownMenuEntry(
        label: 'Z_n (Ring)',
        onPressed: () => ref
            .read(modularArithmeticWorkspaceProvider.notifier)
            .setExplorerType('ring'),
      ),
      AppDropdownMenuEntry(
        label: 'Z_n* (Group)',
        onPressed: () => ref
            .read(modularArithmeticWorkspaceProvider.notifier)
            .setExplorerType('group'),
      ),
      AppDropdownMenuEntry(
        label: 'GF(p) (Field)',
        onPressed: () => ref
            .read(modularArithmeticWorkspaceProvider.notifier)
            .setExplorerType('field'),
      ),
    ];

    return ResponsiveWorkspaceLayout(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 8.0,
        bottom: 8.0 + MediaQuery.paddingOf(context).bottom,
      ),
      gap: const SizedBox(height: 16),
      displayArea: ModularContextCard(
        uiStyle: uiStyle,
        currentTypeLabel: currentLabel,
        typeEntries: typeEntries,
        modulusController: _nController,
        modulusHint: state.explorerType == 'field' ? 'Prime p' : 'n',
        onModulusChanged: (val) {
          ref
              .read(modularArithmeticWorkspaceProvider.notifier)
              .setExplorerN(val);
        },
      ),
      // Unpinned, matching the Evaluator tab one switch away. It used to be the
      // odd one out: a fixed 64px footer pinned below an `Expanded` result
      // region that was itself a box-scroll nested inside a sliver, so the
      // button never moved and the results never scrolled with the content.
      controls: _buildControls(context, state, uiStyle),
      // Same panel as the Evaluator tab, one switch away — the two tabs are one
      // workspace and should offer the same thing.
      sidePanel: RecentHistoryPanel(
        category: HistoryCategory.modularArithmetic,
      ),
    );
  }

  /// The result area and the action, sized to whichever shape the shared layout
  /// hands over.
  ///
  /// The layout is not consistent about this, and the difference is the whole
  /// reason this is a `LayoutBuilder`. Normally the control area is unbounded
  /// and the page scrolls as one surface, so the result takes its own height and
  /// the action follows it. On a short screen the same layout instead hands over
  /// a *fixed box* — a bounded height it picked — because a control area built
  /// on `Expanded`, like the calculator's keypad, has no height of its own and
  /// must be given one.
  ///
  /// A fixed box is a ceiling, not a floor, and this screen's result is not
  /// bounded: an analysis grid of a large ring is far taller than any box the
  /// layout would choose, which overflowed the box and pushed the action out of
  /// the viewport instead of scrolling. So where there is a box, the result
  /// scrolls inside it and the action stays put; where there is not, the result
  /// is left to size itself. Reading the constraint rather than being told which
  /// case it is in keeps the decision with the layout that already knows.
  Widget _buildControls(
    BuildContext context,
    ModularArithmeticWorkspaceState state,
    UiStyle uiStyle,
  ) {
    final theme = Theme.of(context);
    final result = _buildResultArea(context, state, uiStyle, theme);

    final action = SizedBox(
      height: LayoutMetrics.standard.buttonHeight + 8,
      child: AppCalcButton(
        text: state.explorerResult == null
            ? 'Analyze Structure'
            : 'Analyze Again',
        type: ButtonType.equals,
        uiStyle: uiStyle,
        onPressed: () {
          ref.read(modularArithmeticWorkspaceProvider.notifier).analyzeStructure();
          return true;
        },
        icon: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics, size: 20),
            const SizedBox(width: 8),
            Text(
              state.explorerResult == null
                  ? 'Analyze Structure'
                  : 'Analyze Again',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [result, const SizedBox(height: 16), action],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: SingleChildScrollView(child: result)),
            const SizedBox(height: 16),
            action,
          ],
        );
      },
    );
  }

  Widget _buildResultArea(
    BuildContext context,
    ModularArithmeticWorkspaceState state,
    UiStyle uiStyle,
    ThemeData theme,
  ) {
    if (state.explorerSuggestion != null) {
      return Center(
        child: ActionChip(
          avatar: const Icon(Icons.lightbulb_outline),
          label: Text(state.explorerSuggestion!),
          onPressed: () {
            final sug = state.explorerSuggestion!;
            final match = RegExp(r'Did you mean (.*?)\?').firstMatch(sug);
            if (match != null) {
              final corrected = match.group(1)!;
              _nController.text = corrected;
              ref
                  .read(modularArithmeticWorkspaceProvider.notifier)
                  .setExplorerN(corrected);
              ref
                  .read(modularArithmeticWorkspaceProvider.notifier)
                  .analyzeStructure();
            }
          },
        ),
      );
    }

    if (state.explorerError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            state.explorerError!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final res = state.explorerResult;
    if (res == null) {
      return Center(
        child: ModularArithmeticExplorerEmptyState(uiStyle: uiStyle),
      );
    }

    return ModularArithmeticAnalysisGrid(
      uiStyle: uiStyle,
      analysis: res,
      interpretedAs: state.explorerInterpretedAs,
    );
  }
}
