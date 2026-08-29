import 'package:flutter/material.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart'
    as import_app_dialog;
import 'package:calc_flut_rs/app/theme/ui_style.dart';

class SupportedOperationsDialog extends StatefulWidget {
  const SupportedOperationsDialog({super.key});

  static void show(BuildContext context, {required UiStyle uiStyle}) {
    import_app_dialog.showAppDialog(
      context: context,
      title: 'Supported Operations',
      icon: Icons.help_outline,
      uiStyle: uiStyle,
      scrollable: false,
      primaryButtonText: 'Close',
      content: const SizedBox(
        height: 500, // Constrain height since scrollable is false
        child: SupportedOperationsDialog(),
      ),
    );
  }

  @override
  State<SupportedOperationsDialog> createState() =>
      _SupportedOperationsDialogState();
}

class _SupportedOperationsDialogState extends State<SupportedOperationsDialog> {
  String _searchQuery = '';
  late TextEditingController _searchController;

  static const List<Map<String, dynamic>> _categories = [
    {
      'title': 'Basic Modular Arithmetic',
      'items': [
        {'op': 'a mod n', 'desc': 'Modulo operator', 'example': '17 mod 5 = 2'},
        {'op': 'a + b', 'desc': 'Addition', 'example': '3 + 4'},
        {'op': 'a - b', 'desc': 'Subtraction', 'example': '3 - 4'},
        {'op': 'a * b', 'desc': 'Multiplication', 'example': '3 * 4'},
        {
          'op': 'a / b',
          'desc': 'Division (multiplies by modular inverse)',
          'example': '3 / 4',
        },
        {
          'op': 'powmod(a, b, m)',
          'desc': 'Modular exponentiation',
          'example': 'powmod(2, 135, 271)',
        },
        {
          'op': 'inv(a, n)',
          'desc': 'Modular multiplicative inverse',
          'example': 'inv(3, 11) = 4',
        },
      ],
    },
    {
      'title': 'Number Theory',
      'items': [
        {
          'op': 'gcd(a, b)',
          'desc': 'Greatest common divisor',
          'example': 'gcd(12, 15) = 3',
        },
        {
          'op': 'egcd(a, b)',
          'desc':
              'Extended Euclidean algorithm (returns d, x, y where ax+by=d)',
          'example': 'egcd(12, 15)',
        },
        {
          'op': 'phi(n)',
          'desc': 'Euler\'s totient function',
          'example': 'phi(10) = 4',
        },
        {
          'op': 'crt(r1 mod m1, r2 mod m2)',
          'desc': 'Chinese Remainder Theorem',
          'example': 'crt(2 mod 3, 3 mod 5)',
        },
        {
          'op': 'solve(a*x = b mod m)',
          'desc': 'Solve linear congruence',
          'example': 'solve(3*x = 2 mod 5)',
        },
      ],
    },
    {
      'title': 'Group Theory',
      'items': [
        {
          'op': 'order(a, n)',
          'desc': 'Multiplicative order of a modulo n',
          'example': 'order(3, 10)',
        },
        {
          'op': 'primitive_roots(n)',
          'desc': 'Find all primitive roots modulo n',
          'example': 'primitive_roots(7)',
        },
        {
          'op': 'dlog(g, h, p)',
          'desc': 'Discrete logarithm (solve g^x = h mod p)',
          'example': 'dlog(2, 3, 29)',
        },
      ],
    },
    {
      'title': 'Ring & Field Theory',
      'items': [
        {
          'op': 'legendre(a, p)',
          'desc': 'Legendre symbol',
          'example': 'legendre(3, 7)',
        },
        {
          'op': 'jacobi(a, n)',
          'desc': 'Jacobi symbol',
          'example': 'jacobi(3, 15)',
        },
        {
          'op': 'sqrt_mod(a, p)',
          'desc': 'Square root modulo a prime',
          'example': 'sqrt_mod(5, 11)',
        },
        {
          'op': 'analyze_ring(n)',
          'desc':
              'Classify Z_n and find zero divisors, idempotents, nilpotents',
          'example': 'analyze_ring(12)',
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredCategories = _getFilteredCategories();

    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search operations...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.toLowerCase();
            });
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: filteredCategories.length,
            itemBuilder: (context, index) {
              final cat = filteredCategories[index];
              final items = cat['items'] as List<Map<String, String>>;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      cat['title'] as String,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['op']!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['desc']!,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ex: ${item['example']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getFilteredCategories() {
    if (_searchQuery.isEmpty) return _categories;

    return _categories
        .map((cat) {
          final filteredItems = (cat['items'] as List<Map<String, String>>)
              .where((item) {
                return item['op']!.toLowerCase().contains(_searchQuery) ||
                    item['desc']!.toLowerCase().contains(_searchQuery);
              })
              .toList();

          if (filteredItems.isNotEmpty) {
            return {'title': cat['title'], 'items': filteredItems};
          }
          return null;
        })
        .where((cat) => cat != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }
}
