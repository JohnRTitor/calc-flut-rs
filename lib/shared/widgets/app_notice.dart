import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// A frosted, theme-aware banner used for transient, non-blocking notices.
///
/// Renders through [SharedSurface] so it matches both `UiStyle.material` and
/// `UiStyle.liquidGlass`.
class AppNotice extends StatelessWidget {
  final UiStyle uiStyle;
  final String message;
  final IconData? icon;

  const AppNotice({
    super.key,
    required this.uiStyle,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.panel,
      frosted: true,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a short-lived [AppNotice] at the bottom of the screen.
///
/// Resolves the active [UiStyle] from the ambient [ProviderScope] so callers do
/// not have to thread it through purely for presentation purposes.
void showAppNotice(BuildContext context, String message, {IconData? icon}) {
  final uiStyle = ProviderScope.containerOf(context).read(uiStyleProvider);

  toastification.showCustom(
    context: context,
    autoCloseDuration: const Duration(seconds: 2),
    alignment: Alignment.bottomCenter,
    builder: (context, holder) {
      return AppNotice(uiStyle: uiStyle, message: message, icon: icon);
    },
  );
}
