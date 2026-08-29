import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/modular_arithmetic_workspace_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/modular_arithmetic_workspace_state.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
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
    final theme = Theme.of(context);

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

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          sliver: SliverToBoxAdapter(
            child: ModularContextCard(
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
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverFillRemaining(
            hasScrollBody: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Expanded(child: _buildResultArea(context, state, uiStyle, theme)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 64,
                  child: AppCalcButton(
                    text: state.explorerResult == null
                        ? 'Analyze Structure'
                        : 'Analyze Again',
                    type: ButtonType.equals,
                    uiStyle: uiStyle,
                    onPressed: () {
                      ref
                          .read(modularArithmeticWorkspaceProvider.notifier)
                          .analyzeStructure();
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
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
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
