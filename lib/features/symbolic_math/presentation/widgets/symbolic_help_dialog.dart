import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';

/// Explains what a symbolic workspace offers and what it guarantees.
///
/// Shared so every tool in the section answers "what can this do, and how much
/// can I trust it" the same way, from one dialog rather than one per tool.
void showSymbolicHelpDialog({
  required BuildContext context,
  required UiStyle uiStyle,
  required String title,
  required String description,
  List<String> notes = const [],
}) {
  showAppDialog(
    context: context,
    uiStyle: uiStyle,
    title: title,
    icon: Icons.functions,
    primaryButtonText: 'OK',
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(description),
        for (final note in notes) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
