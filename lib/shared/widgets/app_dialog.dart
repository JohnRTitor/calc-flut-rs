import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required IconData icon,
  required UiStyle uiStyle,
  String primaryButtonText = 'OK',
  VoidCallback? onPrimaryButtonPressed,
  String? secondaryButtonText,
  VoidCallback? onSecondaryButtonPressed,
  bool scrollable = true,
  bool isDestructive = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final scaleAnimation = Tween<double>(
        begin: 0.9,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      final fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return ScaleTransition(
        scale: scaleAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: SharedSurface(
              uiStyle: uiStyle,
              glassRole: GlassSurfaceRole.panel,
              frosted: true,
              borderRadius: BorderRadius.circular(32),
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDestructive
                            ? colorScheme.errorContainer.withValues(alpha: 0.5)
                            : colorScheme.primaryContainer.withValues(
                                alpha: 0.5,
                              ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: isDestructive
                            ? colorScheme.error
                            : colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: scrollable
                          ? SingleChildScrollView(child: content)
                          : content,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (secondaryButtonText != null) ...[
                          _buildButton(
                            context: context,
                            text: secondaryButtonText,
                            onPressed: onSecondaryButtonPressed,
                            uiStyle: uiStyle,
                            isPrimary: false,
                            isDestructive: false,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: 8),
                        ],
                        _buildButton(
                          context: context,
                          text: primaryButtonText,
                          onPressed: onPrimaryButtonPressed,
                          uiStyle: uiStyle,
                          isPrimary: true,
                          isDestructive: isDestructive,
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildButton({
  required BuildContext context,
  required String text,
  VoidCallback? onPressed,
  required UiStyle uiStyle,
  required bool isPrimary,
  required bool isDestructive,
  required ColorScheme colorScheme,
}) {
  final handlePress = onPressed ?? () => Navigator.of(context).pop();

  if (uiStyle == UiStyle.liquidGlass) {
    final role = isDestructive
        ? GlassSurfaceRole.destructive
        : (isPrimary ? GlassSurfaceRole.primary : GlassSurfaceRole.accent);

    final style = resolveGlassStyle(
      colorScheme,
      brightness: Theme.of(context).brightness,
      role: role,
      isSelected: true, // We make them pop
    );

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: role,
      isInteractive: true,
      isSelected: true,
      onTap: handlePress,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: style.foregroundColor,
        ),
      ),
    );
  } else {
    if (isPrimary) {
      return FilledButton(
        onPressed: handlePress,
        style: FilledButton.styleFrom(
          backgroundColor: isDestructive ? colorScheme.error : null,
          foregroundColor: isDestructive ? colorScheme.onError : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    } else {
      return TextButton(
        onPressed: handlePress,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    }
  }
}
