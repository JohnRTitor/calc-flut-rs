import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/app/navigation/route_transitions.dart';
import 'package:calc_flut_rs/generated/rust/bridge/converter.dart';
import 'package:calc_flut_rs/features/converter/presentation/providers/converter_provider.dart';
import 'package:calc_flut_rs/features/converter/presentation/screens/converter_detail_screen.dart';

import 'package:calc_flut_rs/features/currency/presentation/screens/loan_calculator_screen.dart';
import 'package:calc_flut_rs/features/currency/presentation/screens/investment_screen.dart';
import 'package:toastification/toastification.dart';

class CurrencyItem {
  final String id;
  final String name;
  final IconData icon;

  const CurrencyItem({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class CurrencyHomeScreen extends ConsumerWidget {
  const CurrencyHomeScreen({super.key});

  static const List<CurrencyItem> items = [
    CurrencyItem(
      id: 'currency',
      name: 'Currency',
      icon: Icons.currency_exchange,
    ),
    CurrencyItem(id: 'loan', name: 'Loan / EMI', icon: Icons.real_estate_agent),
    CurrencyItem(id: 'investment', name: 'Investment', icon: Icons.trending_up),
    CurrencyItem(id: 'discount', name: 'Discount', icon: Icons.local_offer),
    CurrencyItem(id: 'gst', name: 'GST', icon: Icons.receipt_long),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiStyle = ref.watch(uiStyleProvider);
    // Explicitly depend on Theme to ensure the grid rebuilds when theme changes
    final _ = Theme.of(context);

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
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          return SharedSurface(
            uiStyle: uiStyle,
            onTap: () {
              if (item.id == 'loan') {
                Navigator.push(
                  context,
                  FadePageRoute(page: const LoanCalculatorScreen()),
                );
              } else if (item.id == 'investment') {
                Navigator.push(
                  context,
                  FadePageRoute(page: const InvestmentScreen()),
                );
              } else if (item.id == 'currency' ||
                  item.id == 'discount' ||
                  item.id == 'gst') {
                final cat = FfiConverterCategory(
                  id: item.id,
                  name: item.name,
                  iconName: '', // not strictly needed for the detail screen
                  units: [],
                  showSwapUnitsToggler: item.id == 'currency',
                  showResultSection: true,
                );
                ref.read(converterProvider.notifier).setCategory(cat);
                Navigator.push(
                  context,
                  FadePageRoute(page: const ConverterDetailScreen()),
                );
              } else {
                toastification.showCustom(
                  context: context,
                  autoCloseDuration: const Duration(seconds: 2),
                  alignment: Alignment.bottomCenter,
                  builder: (context, holder) {
                    return SharedSurface(
                      uiStyle: uiStyle,
                      glassRole: GlassSurfaceRole.panel,
                      frosted: true,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Text(
                        '${item.name} Coming Soon',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
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
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.12)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    size: 32,
                    color: uiStyle == UiStyle.liquidGlass
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  item.name,
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
          );
        },
      ),
    );
  }
}
