import 'package:flutter/material.dart';
import 'package:calc_flut_rs/generated/rust/bridge/converter.dart';
import '../../../../app/theme/ui_style.dart';
import '../../../../shared/widgets/glass_utils.dart';

/// A modal bottom sheet allowing users to search and select a specific unit
/// from a provided list of units, presented as a floating glass sheet.
class UnitSelectorBottomSheet extends StatefulWidget {
  final List<FfiUnit> units;
  final FfiUnit? selectedUnit;
  final Function(FfiUnit) onSelect;
  final String categoryId;
  final UiStyle uiStyle;

  const UnitSelectorBottomSheet({
    super.key,
    required this.units,
    required this.selectedUnit,
    required this.onSelect,
    required this.categoryId,
    required this.uiStyle,
  });

  @override
  State<UnitSelectorBottomSheet> createState() =>
      _UnitSelectorBottomSheetState();
}

class _UnitSelectorBottomSheetState extends State<UnitSelectorBottomSheet> {
  String _searchQuery = '';

  IconData _getIconForCategory(String categoryId) {
    switch (categoryId) {
      case 'length':
        return Icons.straighten_rounded;
      case 'weight':
        return Icons.scale_rounded;
      case 'temperature':
        return Icons.thermostat_rounded;
      case 'currency':
        return Icons.attach_money_rounded;
      case 'bmi':
        return Icons.monitor_weight_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGlass = widget.uiStyle == UiStyle.liquidGlass;

    final filteredUnits = widget.units.where((u) {
      final query = _searchQuery.toLowerCase();
      return u.name.toLowerCase().contains(query) ||
          u.symbol.toLowerCase().contains(query) ||
          u.id.toLowerCase().contains(query);
    }).toList();

    return SharedSurface(
      uiStyle: widget.uiStyle,
      glassRole: GlassSurfaceRole.panel,
      materialColor: colorScheme.surfaceContainerHigh,
      frosted: true,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(32),
        bottom: Radius.circular(32),
      ),
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          // Drag Handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search units',
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colorScheme.primary,
                    ),
                    filled: true,
                    fillColor: isGlass
                        ? colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          )
                        : colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredUnits.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final unit = filteredUnits[index];
                final isSelected = widget.selectedUnit?.id == unit.id;

                return _buildUnitItem(
                  context,
                  unit: unit,
                  isSelected: isSelected,
                  colorScheme: colorScheme,
                  isGlass: isGlass,
                  icon: _getIconForCategory(widget.categoryId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitItem(
    BuildContext context, {
    required FfiUnit unit,
    required bool isSelected,
    required ColorScheme colorScheme,
    required bool isGlass,
    required IconData icon,
  }) {
    final bgColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: isGlass ? 0.7 : 1.0)
        : Colors.transparent;

    final iconBgColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.2)
        : colorScheme.surfaceContainerHighest.withValues(
            alpha: isGlass ? 0.5 : 1.0,
          );

    final iconColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final titleColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final subtitleColor = isSelected
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
        : colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: isSelected && isGlass
            ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            widget.onSelect(unit);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Leading Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                // Titles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: titleColor,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                      Text(
                        unit.symbol,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: subtitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trailing Checkmark
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
