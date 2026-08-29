import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:flutter/services.dart';

class UtilitiesKeypad extends ConsumerWidget {
  final void Function(String) onKeyPressed;

  const UtilitiesKeypad({super.key, required this.onKeyPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiStyle = ref.watch(uiStyleProvider);
    final isGlass = uiStyle == UiStyle.liquidGlass;

    final keys = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['.', '0', '⌫'],
    ];

    return Container(
      decoration: BoxDecoration(
        color: isGlass ? null : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: isGlass
            ? Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: isGlass
              ? ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.1),
                  BlendMode.srcOver,
                )
              : const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: keys.map((row) {
                      return Expanded(
                        child: Row(
                          children: row.map((key) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildKey(context, key, uiStyle),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKey(BuildContext context, String label, UiStyle uiStyle) {
    final colorScheme = Theme.of(context).colorScheme;

    final isAction = label == '⌫';

    return SharedSurface(
      uiStyle: uiStyle,
      isInteractive: true,
      glassRole: isAction
          ? GlassSurfaceRole.destructive
          : GlassSurfaceRole.button,
      materialColor: isAction
          ? colorScheme.tertiaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24.0),
      onTap: () {
        HapticFeedback.lightImpact();
        onKeyPressed(label);
      },
      child: Center(
        child: label == '⌫'
            ? Icon(
                Icons.backspace_outlined,
                color: uiStyle == UiStyle.liquidGlass
                    ? colorScheme.error
                    : colorScheme.onErrorContainer,
                size: 24,
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: isAction
                      ? (uiStyle == UiStyle.liquidGlass
                            ? colorScheme.error
                            : colorScheme.onErrorContainer)
                      : colorScheme.onSurface,
                ),
              ),
      ),
    );
  }
}
