import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// The expression editor shared by every symbolic workspace.
///
/// Owns its own [TextEditingController]: rebuilding one from `build` would
/// reset the caret on every keystroke. The field follows [expression] only when
/// the value changes from outside — a history restore, say — so ordinary typing
/// is never interrupted.
class SymbolicExpressionEditor extends StatefulWidget {
  final UiStyle uiStyle;

  /// The expression as typed, and as the user changes it.
  final String expression;

  /// Placeholder shown while the field is empty.
  final String hintText;

  /// Invoked on every edit.
  final ValueChanged<String> onChanged;

  /// Opens the workspace's reference dialog.
  final VoidCallback onShowHelp;

  const SymbolicExpressionEditor({
    super.key,
    required this.uiStyle,
    required this.expression,
    required this.onChanged,
    required this.onShowHelp,
    this.hintText = '(x + 1)^2',
  });

  @override
  State<SymbolicExpressionEditor> createState() =>
      _SymbolicExpressionEditorState();
}

class _SymbolicExpressionEditorState extends State<SymbolicExpressionEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.expression);
  }

  @override
  void didUpdateWidget(SymbolicExpressionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only adopt an externally-changed value. Echoing back what the user is
    // mid-way through typing would move the caret out from under them.
    if (widget.expression != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.expression,
        selection: TextSelection.collapsed(offset: widget.expression.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SharedSurface(
      uiStyle: widget.uiStyle,
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
              hintText: widget.hintText,
              hintStyle: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              // Leave room for the help icon.
              contentPadding: const EdgeInsets.only(right: 40),
            ),
            onChanged: widget.onChanged,
          ),
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: widget.onShowHelp,
              tooltip: 'Supported operations',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of chips for choosing which variable an operation acts on.
///
/// These are selectors, not value fields: nothing is substituted, the variable
/// stays free. That is why a single tap is enough, and why the row is absent
/// entirely when the expression has no variables — there is nothing to choose.
class SymbolicVariableSelector extends StatelessWidget {
  final UiStyle uiStyle;
  final List<String> variables;
  final String? selectedVariable;
  final ValueChanged<String> onSelected;

  const SymbolicVariableSelector({
    super.key,
    required this.uiStyle,
    required this.variables,
    required this.selectedVariable,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (variables.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final variable in variables)
            SymbolicVariableChip(
              uiStyle: uiStyle,
              name: variable,
              isSelected: variable == selectedVariable,
              onTap: () => onSelected(variable),
            ),
        ],
      ),
    );
  }
}

/// A single selectable variable chip.
class SymbolicVariableChip extends StatelessWidget {
  final UiStyle uiStyle;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const SymbolicVariableChip({
    super.key,
    required this.uiStyle,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeExt = theme.extension<AppThemeExtension>()!;
    final colorScheme = theme.colorScheme;

    final background = isSelected
        ? colorScheme.primaryContainer
        : themeExt.chipBackground;
    final foreground = isSelected
        ? colorScheme.onPrimaryContainer
        : themeExt.chipText;

    return Tooltip(
      message: isSelected
          ? 'Operations will use $name'
          : 'Use $name for operations that need one variable',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: AppChip.minimumTouchTarget,
              minHeight: AppChip.minimumTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
