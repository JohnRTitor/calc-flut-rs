import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calculator_flutter_app/generated/rust/bridge/converter.dart';
import 'package:calculator_flutter_app/features/converter/presentation/providers/converter_provider.dart';
import 'package:calculator_flutter_app/features/converter/presentation/screens/converter_detail_screen.dart';
import 'package:calculator_flutter_app/features/converter/presentation/screens/date_calculator_screen.dart';
import 'package:calculator_flutter_app/features/settings/presentation/providers/theme_provider.dart';
import 'package:calculator_flutter_app/app/theme/ui_style.dart';
import 'package:calculator_flutter_app/shared/widgets/glass_utils.dart';
import 'package:calculator_flutter_app/app/navigation/route_transitions.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The entry point screen for the Unit Converter feature.
///
/// Displays a grid of available converter categories (e.g., Length, Mass, BMI, Date Difference).
/// Tapping a category navigates to the `ConverterDetailScreen` with that category pre-selected.
class ConverterHomeScreen extends ConsumerStatefulWidget {
  const ConverterHomeScreen({super.key});

  @override
  ConsumerState<ConverterHomeScreen> createState() =>
      _ConverterHomeScreenState();
}

class _ConverterHomeScreenState extends ConsumerState<ConverterHomeScreen> {
  List<FfiConverterCategory>? categories;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    final cats = getConverterCategories();
    if (mounted) {
      setState(() {
        categories = cats;
      });
    }
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'straighten':
        return Icons.straighten;
      case 'texture':
        return Icons.texture;
      case 'scale':
        return Icons.scale;
      case 'water_drop':
        return Icons.water_drop;
      case 'thermostat':
        return Icons.thermostat;
      case 'speed':
        return Icons.speed;
      case 'schedule':
        return Icons.schedule;
      case 'storage':
        return Icons.storage;
      case 'pin':
        return Icons.pin;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (categories == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final uiStyle = ref.watch(uiStyleProvider);
    // Explicitly depend on Theme to ensure the grid rebuilds when theme changes
    final _ = Theme.of(context);

    // Add extra items to match user request (Date Difference, BMI)
    final displayCategories = [
      FfiConverterCategory(
        id: 'date',
        name: 'Date Difference',
        iconName: 'calendar_month',
        units: [],
        showSwapUnitsToggler: false,
        showResultSection: false,
      ),
      FfiConverterCategory(
        id: 'bmi',
        name: 'BMI',
        iconName: 'monitor_weight',
        units: [],
        showSwapUnitsToggler: false,
        showResultSection: true,
      ),
      ...categories!,
    ];

    return Scaffold(
      body: GridView.builder(
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 24.0,
          bottom: 24.0 + MediaQuery.paddingOf(context).bottom,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150.0,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 24.0,
          childAspectRatio: 0.8,
        ),
        itemCount: displayCategories.length,
        itemBuilder: (context, index) {
          final cat = displayCategories[index];
          IconData iconData = _getIcon(cat.iconName);
          if (cat.id == 'date') iconData = Icons.calendar_month;
          if (cat.id == 'bmi') iconData = Icons.monitor_weight;

          return SharedSurface(
                uiStyle: uiStyle,
                onTap: () {
                  if (cat.id == 'date') {
                    Navigator.push(
                      context,
                      FadePageRoute(page: const DateCalculatorScreen()),
                    );
                  } else {
                    ref.read(converterProvider.notifier).setCategory(cat);
                    Navigator.push(
                      context,
                      FadePageRoute(page: const ConverterDetailScreen()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(24.0),
                isInteractive: true,
                glassRole: GlassSurfaceRole.card,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: uiStyle == UiStyle.liquidGlass
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.12)
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconData,
                        size: 32,
                        color: uiStyle == UiStyle.liquidGlass
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      cat.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
              .animate()
              .fade(duration: 400.ms, delay: (index * 50).ms)
              .slideY(
                begin: 0.2,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutQuart,
              );
        },
      ),
    );
  }
}
