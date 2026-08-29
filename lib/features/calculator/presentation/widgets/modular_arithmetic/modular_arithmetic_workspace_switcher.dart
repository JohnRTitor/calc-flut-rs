import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/pill_switcher.dart';

class ModularArithmeticWorkspaceSwitcher extends StatelessWidget {
  final UiStyle uiStyle;
  final bool isEvaluatorSelected;
  final ValueChanged<bool> onEvaluatorSelected;

  const ModularArithmeticWorkspaceSwitcher({
    super.key,
    required this.uiStyle,
    required this.isEvaluatorSelected,
    required this.onEvaluatorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: PillSwitcher(
          uiStyle: uiStyle,
          label1: 'Evaluator',
          tooltip1: 'Evaluate modular arithmetic expressions',
          label2: 'Structure Explorer',
          tooltip2: 'Explore mathematical structures like Z_n and GF(p)',
          isFirstSelected: isEvaluatorSelected,
          onChanged: onEvaluatorSelected,
        ),
      ),
    );
  }
}
