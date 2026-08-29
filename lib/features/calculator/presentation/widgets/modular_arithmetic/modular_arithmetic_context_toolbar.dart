import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/app_dropdown_menu.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

class ModularArithmeticContextToolbar extends StatelessWidget {
  final UiStyle uiStyle;
  final String currentTypeLabel;
  final List<AppDropdownMenuEntry> typeEntries;
  final TextEditingController modulusController;
  final String modulusHint;
  final ValueChanged<String> onModulusChanged;
  final bool showModulusPrefix;

  const ModularArithmeticContextToolbar({
    super.key,
    required this.uiStyle,
    required this.currentTypeLabel,
    required this.typeEntries,
    required this.modulusController,
    required this.modulusHint,
    required this.onModulusChanged,
    this.showModulusPrefix = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: AppDropdownMenu(
              label: currentTypeLabel,
              uiStyle: uiStyle,
              isExpanded: true,
              entries: typeEntries,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 1, child: _buildModulusInput(context)),
        ],
      ),
    );
  }

  Widget _buildModulusInput(BuildContext context) {
    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      frosted: true,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: modulusController,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: modulusHint,
          prefixText: showModulusPrefix ? 'mod ' : null,
        ),
        onChanged: onModulusChanged,
      ),
    );
  }
}
