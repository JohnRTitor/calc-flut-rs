import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/modular_arithmetic_workspace_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/modular_arithmetic_workspace_state.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/structure_explorer.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_onboarding_overlay.dart';
import 'package:calc_flut_rs/shared/widgets/app_button.dart';
import 'package:calc_flut_rs/shared/widgets/app_dropdown_menu.dart';

import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_arithmetic_workspace_switcher.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_context_card.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_arithmetic_expression_editor.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_arithmetic_result_card.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_arithmetic_help_bottom_sheet.dart';

class ModularArithmeticWorkspaceScreen extends ConsumerStatefulWidget {
  const ModularArithmeticWorkspaceScreen({super.key});

  @override
  ConsumerState<ModularArithmeticWorkspaceScreen> createState() =>
      _ModularArithmeticWorkspaceScreenState();
}

class _ModularArithmeticWorkspaceScreenState
    extends ConsumerState<ModularArithmeticWorkspaceScreen> {
  late TextEditingController _exprController;
  late TextEditingController _modController;
  bool _isEvaluatorSelected = true;

  @override
  void initState() {
    super.initState();
    final state = ref.read(modularArithmeticWorkspaceProvider);
    _exprController = TextEditingController(text: state.expression);
    _modController = TextEditingController(text: state.modulus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ModularOnboardingOverlay.checkAndShow(context);
    });
  }

  @override
  void dispose() {
    _exprController.dispose();
    _modController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      modularArithmeticWorkspaceProvider.select((state) => state.expression),
      (previous, next) {
        if (_exprController.text != next) {
          _exprController.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
      },
    );

    ref.listen(
      modularArithmeticWorkspaceProvider.select((state) => state.modulus),
      (previous, next) {
        if (_modController.text != next) {
          _modController.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
      },
    );

    final uiStyle = ref.watch(uiStyleProvider);

    return Column(
      children: [
        ModularArithmeticWorkspaceSwitcher(
          uiStyle: uiStyle,
          isEvaluatorSelected: _isEvaluatorSelected,
          onEvaluatorSelected: (val) {
            setState(() {
              _isEvaluatorSelected = val;
            });
          },
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _isEvaluatorSelected
                ? _buildEvaluatorTab(uiStyle)
                : const StructureExplorer(),
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluatorTab(UiStyle uiStyle) {
    final state = ref.watch(modularArithmeticWorkspaceProvider);

    String currentLabel;
    switch (state.mode) {
      case ModularMode.ring:
        currentLabel = 'Z/nZ (Ring)';
        break;
      case ModularMode.field:
        currentLabel = 'GF(p) (Field)';
        break;
      case ModularMode.crt:
        currentLabel = 'CRT Solver';
        break;
    }

    final typeEntries = [
      AppDropdownMenuEntry(
        label: 'Z/nZ (Ring)',
        onPressed: () => ref
            .read(modularArithmeticWorkspaceProvider.notifier)
            .setMode(ModularMode.ring),
      ),
      AppDropdownMenuEntry(
        label: 'GF(p) (Field)',
        onPressed: () => ref
            .read(modularArithmeticWorkspaceProvider.notifier)
            .setMode(ModularMode.field),
      ),
      AppDropdownMenuEntry(
        label: 'CRT Solver',
        onPressed: () => ref
            .read(modularArithmeticWorkspaceProvider.notifier)
            .setMode(ModularMode.crt),
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
              modulusController: _modController,
              modulusHint: state.mode == ModularMode.field
                  ? 'Prime p'
                  : 'Modulus n',
              onModulusChanged: (val) {
                ref
                    .read(modularArithmeticWorkspaceProvider.notifier)
                    .updateModulus(val);
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverToBoxAdapter(
            child: ModularArithmeticExpressionEditor(
              uiStyle: uiStyle,
              controller: _exprController,
              hintText: state.mode == ModularMode.crt
                  ? 'crt(rem1 mod mod1, ...)'
                  : 'e.g. powmod(2, 10) or 5 + 7',
              onChanged: (val) {
                ref
                    .read(modularArithmeticWorkspaceProvider.notifier)
                    .updateExpression(val);
              },
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 8.0,
            bottom: 8.0 + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                ModularArithmeticResultCard(
                  uiStyle: uiStyle,
                  error: state.error,
                  result: state.result,
                  details: state.details,
                  steps: state.steps,
                  preview: state.preview,
                  showResult: state.showResult,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 64,
                  child: AppCalcButton(
                    text: 'Evaluate',
                    type: ButtonType.equals,
                    uiStyle: uiStyle,
                    onPressed: () {
                      ref
                          .read(modularArithmeticWorkspaceProvider.notifier)
                          .evaluate();
                      return true;
                    },
                    icon: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calculate, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Evaluate',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      ModularArithmeticHelpBottomSheet.show(
                        context,
                        uiStyle: uiStyle,
                      );
                    },
                    icon: Icon(
                      Icons.help_outline,
                      color: uiStyle == UiStyle.liquidGlass
                          ? Colors.white70
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      'Examples & Help',
                      style: TextStyle(
                        color: uiStyle == UiStyle.liquidGlass
                            ? Colors.white70
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
}
