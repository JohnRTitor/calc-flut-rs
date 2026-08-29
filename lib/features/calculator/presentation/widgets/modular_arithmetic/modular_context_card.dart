import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/app_dropdown_menu.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

class ModularContextCard extends StatelessWidget {
  final UiStyle uiStyle;
  final String currentTypeLabel;
  final List<AppDropdownMenuEntry> typeEntries;
  final TextEditingController modulusController;
  final String modulusHint;
  final ValueChanged<String> onModulusChanged;

  const ModularContextCard({
    super.key,
    required this.uiStyle,
    required this.currentTypeLabel,
    required this.typeEntries,
    required this.modulusController,
    required this.modulusHint,
    required this.onModulusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGlass = uiStyle == UiStyle.liquidGlass;

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      frosted: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Context',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isGlass ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          AppDropdownMenu(
            label: 'Ring: $currentTypeLabel',
            uiStyle: uiStyle,
            entries: typeEntries,
            isExpanded: true,
          ),
          const SizedBox(height: 12),
          SharedSurface(
             uiStyle: uiStyle,
             glassRole: GlassSurfaceRole.card,
             frosted: true,
             borderRadius: BorderRadius.circular(16),
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
             child: TextField(
               controller: modulusController,
               keyboardType: TextInputType.text,
               decoration: InputDecoration(
                 border: InputBorder.none,
                 hintText: modulusHint,
                 prefixText: 'Modulus: ',
                 prefixStyle: theme.textTheme.bodyLarge?.copyWith(
                   fontWeight: FontWeight.bold,
                   color: isGlass ? Colors.white : theme.colorScheme.onSurface,
                 ),
               ),
               style: theme.textTheme.bodyLarge,
               onChanged: onModulusChanged,
             ),
          ),
        ],
      ),
    );
  }
}
