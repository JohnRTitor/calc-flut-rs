import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/app/navigation/tool_registry.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/app_hub_grid.dart';

/// The home surface of the Symbolic Math section.
///
/// An open-ended tool family (algebra, equation solving, calculus, matrices,
/// number theory, modular arithmetic) that is expected to keep growing, so it
/// uses the Hub Grid pattern rather than a segmented workspace switcher. Every
/// card is registered in `tool_registry.dart`.
class SymbolicMathHomeScreen extends ConsumerWidget {
  const SymbolicMathHomeScreen({super.key});

  /// The registry id of the section this screen renders.
  static const String sectionId = 'symbolic_math';

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
