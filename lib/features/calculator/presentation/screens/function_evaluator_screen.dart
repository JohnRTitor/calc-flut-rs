import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/function_evaluator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/variable_bottom_sheet.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/layouts/responsive_workspace_layout.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/shared/widgets/scrollable_math_result.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';

import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/widgets/recent_history_panel.dart';

class FunctionEvaluatorScreen extends ConsumerStatefulWidget {
  const FunctionEvaluatorScreen({super.key});

  @override
  ConsumerState<FunctionEvaluatorScreen> createState() =>
      _FunctionEvaluatorScreenState();
}

class _FunctionEvaluatorScreenState
    extends ConsumerState<FunctionEvaluatorScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialText = ref.read(functionEvaluatorProvider).funcExpression;
    _controller = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VariableBottomSheet(),
    );
  }

  void _showFunctionsDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isGlass = ref.read(uiStyleProvider) == UiStyle.liquidGlass;

    showAppDialog(
      context: context,
      uiStyle: ref.read(uiStyleProvider),
      title: 'Supported Functions',
      icon: Icons.functions,
      primaryButtonText: 'OK',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The following mathematical functions and constants are supported by the evaluator:',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                      'sin(x)',
                      'cos(x)',
                      'tan(x)',
                      'asin(x)',
                      'acos(x)',
                      'atan(x)',
                      'sinh(x)',
                      'cosh(x)',
                      'tanh(x)',
                      'asinh(x)',
                      'acosh(x)',
                      'atanh(x)',
                      'log(x)',
                      'log_(base, val)',
                      'ln(x)',
                      'sqrt(x)',
                      'x mod y',
                      'x % y',
                      'x!',
                      'ans',
                      'pi (π)',
                      'e',
                    ]
                    .map(
                      (f) => Chip(
                        label: Text(f),
                        backgroundColor: theme
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: isGlass ? 0.3 : 1.0),
                        side: BorderSide.none,
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      functionEvaluatorProvider.select((state) => state.funcExpression),
      (previous, next) {
        if (_controller.text != next) {
          _controller.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
      },
    );

    final state = ref.watch(functionEvaluatorProvider);
    final uiStyle = ref.watch(uiStyleProvider);
    final theme = Theme.of(context);
    final themeExt = theme.extension<AppThemeExtension>()!;

    return ResponsiveWorkspaceLayout(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 8.0,
        bottom: 8.0 + MediaQuery.paddingOf(context).bottom,
      ),
      gap: SizedBox(height: LayoutMetrics.standard.spacing),
      displayArea: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Function Editor
          SharedSurface(
            uiStyle: uiStyle,
            glassRole: GlassSurfaceRole.card,
            frosted: true,
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 2,
                  style: theme.textTheme.headlineSmall,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'f(x, y, z) = x^2 + y^2 + z^2',
                    hintStyle: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    contentPadding: const EdgeInsets.only(
                      right: 40,
                    ), // leave space for info icon
                  ),
                  onChanged: (val) {
                    ref
                        .read(functionEvaluatorProvider.notifier)
                        .setExpression(val);
                  },
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showFunctionsDialog(context),
                    tooltip: 'Supported Functions',
                    color: onGlassSecondary(context, uiStyle),
                  ),
                ),
              ],
            ),
          ),
          if (state.detectedVariables.isNotEmpty) ...[
            SizedBox(height: LayoutMetrics.standard.spacing),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.detectedVariables.map((variable) {
                  final val = state.variables[variable] ?? 0.0;
                  final displayVal = val == val.truncateToDouble()
                      ? val.toInt().toString()
                      : val.toString();
                  return ActionChip(
                    label: Text('[$variable = $displayVal]'),
                    onPressed: _showBottomSheet,
                    backgroundColor: themeExt.chipBackground,
                    labelStyle: theme.textTheme.titleMedium?.copyWith(
                      color: themeExt.chipText,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
      // Unpinned, so the result sits directly under the function that produced
      // it rather than being pushed to the bottom of whatever the viewport
      // happens to be. This is the screen where the user is reasoning about a
      // multi-variable function, so the answer and the action belong next to
      // the question — a `Spacer()` between them left half the screen empty and
      // put the result out of thumb reach.
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SharedSurface(
            uiStyle: uiStyle,
            glassRole: GlassSurfaceRole.primary,
            materialColor: themeExt.resultCard,
            frosted: true,
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Result',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: themeExt.resultText.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                ScrollableMathResult(
                  uiStyle: uiStyle,
                  expression: state.showResult
                      ? (state.exactResult ?? state.result)
                      : (state.preview.isEmpty ? '0' : state.preview),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: themeExt.resultText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: LayoutMetrics.standard.spacing),
          // Angle Mode Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('DEG')),
                  ButtonSegment(value: false, label: Text('RAD')),
                ],
                selected: {state.isDegreeMode},
                onSelectionChanged: (Set<bool> newSelection) {
                  if (newSelection.first != state.isDegreeMode) {
                    ref
                        .read(functionEvaluatorProvider.notifier)
                        .toggleAngleMode();
                  }
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: themeExt.chipBackground,
                  selectedForegroundColor: themeExt.chipText,
                  selectedBackgroundColor: theme.colorScheme.primaryContainer,
                ),
              ),
            ],
          ),
          SizedBox(height: LayoutMetrics.standard.spacing),
          // Evaluate Button
          SizedBox(
            width: double.infinity,
            height: LayoutMetrics.standard.buttonHeight,
            child: uiStyle == UiStyle.liquidGlass
                ? SharedSurface(
                    uiStyle: uiStyle,
                    isInteractive: true,
                    isSelected: true,
                    glassRole: GlassSurfaceRole.primary,
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      ref.read(functionEvaluatorProvider.notifier).evaluate();
                      FocusScope.of(context).unfocus();
                    },
                    child: Center(
                      child: Text(
                        'Evaluate',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  )
                : FilledButton(
                    onPressed: () {
                      ref.read(functionEvaluatorProvider.notifier).evaluate();
                      FocusScope.of(context).unfocus();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Evaluate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      // On a desktop-class window, this tool's own recent results beside it.
      // Everywhere else the width is worth more to the editor than to a list.
      sidePanel: RecentHistoryPanel(
        category: HistoryCategory.functionEvaluator,
      ),
    );
  }
}
