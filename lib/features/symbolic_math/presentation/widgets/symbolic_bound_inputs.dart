import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// The lower and upper bounds of a definite integral.
///
/// Two small fields rather than a second expression box, so the reading is
/// `f(x)` between `a` and `b` rather than two more things to parse. Both are
/// required: defaulting a missing bound to zero would answer a different
/// question than the one asked, so the workspace refuses to run without them.
class SymbolicBoundInputs extends StatelessWidget {
  final UiStyle uiStyle;
  final String lowerBound;
  final String upperBound;
  final ValueChanged<String> onLowerChanged;
  final ValueChanged<String> onUpperChanged;

  const SymbolicBoundInputs({
    super.key,
    required this.uiStyle,
    required this.lowerBound,
    required this.upperBound,
    required this.onLowerChanged,
    required this.onUpperChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BoundField(
            uiStyle: uiStyle,
            label: 'From',
            value: lowerBound,
            onChanged: onLowerChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BoundField(
            uiStyle: uiStyle,
            label: 'To',
            value: upperBound,
            onChanged: onUpperChanged,
          ),
        ),
      ],
    );
  }
}

/// One bound field.
class _BoundField extends StatefulWidget {
  final UiStyle uiStyle;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _BoundField({
    required this.uiStyle,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_BoundField> createState() => _BoundFieldState();
}

class _BoundFieldState extends State<_BoundField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_BoundField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt only an externally-changed value, so typing is never interrupted.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
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
    final themeExt = theme.extension<AppThemeExtension>()!;
    final isGlass = widget.uiStyle == UiStyle.liquidGlass;

    return SharedSurface(
      uiStyle: widget.uiStyle,
      glassRole: GlassSurfaceRole.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Text(
            widget.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: themeExt.chipText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ConstrainedBox(
              // Meets the app's 40dp touch target without a bulky second card.
              constraints: const BoxConstraints(
                minHeight: AppChip.minimumTouchTarget,
              ),
              child: TextField(
                controller: _controller,
                style: theme.textTheme.titleMedium,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  filled: false,
                  fillColor: isGlass
                      ? Colors.transparent
                      : theme.colorScheme.surfaceContainerHighest,
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
