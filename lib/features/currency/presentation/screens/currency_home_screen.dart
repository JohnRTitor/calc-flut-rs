import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/app/navigation/tool_registry.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/app_hub_grid.dart';

/// The entry point screen for the Currency & Finance feature.
///
/// Renders the tools registered for the `currency` section as a hub grid.
class CurrencyHomeScreen extends ConsumerWidget {
  const CurrencyHomeScreen({super.key});

  /// The registry id of the section this screen renders.
  static const String sectionId = 'currency';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiStyle = ref.watch(uiStyleProvider);
    final section = appSectionById(sectionId)!;

    return AppHubGrid(
      uiStyle: uiStyle,
      items: appHubItemsForTools(context, ref, section.tools),
    );
  }
}
