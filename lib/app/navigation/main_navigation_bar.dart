import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/features/calculator/presentation/screens/calculator_screen.dart';
import 'package:calc_flut_rs/features/converter/presentation/screens/converter_home_screen.dart';
import 'package:calc_flut_rs/features/currency/presentation/screens/currency_home_screen.dart';

import 'package:calc_flut_rs/features/settings/presentation/screens/settings_screen.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/app_tab_bar.dart';
import 'package:calc_flut_rs/app/navigation/route_transitions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';
import 'package:calc_flut_rs/shared/widgets/app_dropdown_menu.dart';

/// The primary navigation scaffold of the application.
///
/// Contains a top tab bar to switch between the Calculator and Converter screens,
/// and provides access to the History and Settings screens.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uiStyle = ref.watch(uiStyleProvider);

    if (uiStyle == UiStyle.liquidGlass) {
      return _buildGlassLayout(context, uiStyle);
    }
    return _buildMaterialLayout(context, uiStyle);
  }

  Widget _buildMaterialLayout(BuildContext context, UiStyle uiStyle) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(colorScheme, textTheme, uiStyle),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const CalculatorScreen(),
                  const ConverterHomeScreen(),
                  const CurrencyHomeScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassLayout(BuildContext context, UiStyle uiStyle) {
    // Both styles now use the same Scaffold, but the global background handles the glass aesthetic
    return _buildMaterialLayout(context, uiStyle);
  }

  Widget _buildTopBar(
    ColorScheme colorScheme,
    TextTheme textTheme,
    UiStyle uiStyle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            // Empty space to balance the More Menu on the right and keep tabs centered
            const SizedBox(width: 40),

            const Spacer(),

            // TabBar (Pill Switcher)
            AppTabBar(
              controller: _tabController,
              uiStyle: uiStyle,
              width: 200,
              height: 36,
              tabs: const [
                Tab(icon: Icon(Icons.calculate_outlined, size: 20)),
                Tab(icon: Icon(Icons.swap_horiz_outlined, size: 20)),
                Tab(icon: Icon(Icons.attach_money_outlined, size: 20)),
              ],
            ),

            const Spacer(),

            // More Menu
            AppDropdownMenu(
              icon: Icons.more_vert,
              uiStyle: uiStyle,
              tooltip: 'More options',
              entries: [
                AppDropdownMenuEntry(
                  label: 'Settings',
                  onPressed: () {
                    Navigator.push(
                      context,
                      FadePageRoute(page: const SettingsScreen()),
                    );
                  },
                ),
                AppDropdownMenuEntry(
                  label: 'About',
                  onPressed: () => _showAboutDialog(context, uiStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, UiStyle uiStyle) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showAppDialog(
      context: context,
      title: 'About',
      icon: Icons.info_outline,
      uiStyle: uiStyle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Masum Reza (JohnRTitor)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Flutter + Rust Native Calculator\nBuilt for performance and elegance.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
      primaryButtonText: 'View Source Code',
      onPrimaryButtonPressed: () async {
        final url = Uri.parse(
          'https://github.com/JohnRTitor/calc_flut_rs',
        );
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      secondaryButtonText: 'Close',
    );
  }
}
