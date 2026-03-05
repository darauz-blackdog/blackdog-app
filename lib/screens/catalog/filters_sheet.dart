import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';

class FilterResult {
  final String? brand;
  final String sort;
  final bool inStockOnly;

  const FilterResult({
    this.brand,
    this.sort = 'name',
    this.inStockOnly = false,
  });
}

void showFiltersSheet({
  required BuildContext context,
  required WidgetRef ref,
  int? appCategoryId,
  String? currentBrand,
  String currentSort = 'name',
  bool currentInStockOnly = false,
  required void Function(FilterResult) onApply,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FiltersSheetContent(
      ref: ref,
      appCategoryId: appCategoryId,
      initialBrand: currentBrand,
      initialSort: currentSort,
      initialInStockOnly: currentInStockOnly,
      onApply: onApply,
    ),
  );
}

class _FiltersSheetContent extends StatefulWidget {
  final WidgetRef ref;
  final int? appCategoryId;
  final String? initialBrand;
  final String initialSort;
  final bool initialInStockOnly;
  final void Function(FilterResult) onApply;

  const _FiltersSheetContent({
    required this.ref,
    this.appCategoryId,
    this.initialBrand,
    required this.initialSort,
    required this.initialInStockOnly,
    required this.onApply,
  });

  @override
  State<_FiltersSheetContent> createState() => _FiltersSheetContentState();
}

class _FiltersSheetContentState extends State<_FiltersSheetContent> {
  late String? _selectedBrand;
  late String _selectedSort;
  late bool _inStockOnly;

  static const _sortOptions = [
    ('name', 'Nombre A-Z'),
    ('price_asc', 'Precio menor'),
    ('price_desc', 'Precio mayor'),
    ('newest', 'Más recientes'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedBrand = widget.initialBrand;
    _selectedSort = widget.initialSort;
    _inStockOnly = widget.initialInStockOnly;
  }

  void _reset() {
    setState(() {
      _selectedBrand = null;
      _selectedSort = 'name';
      _inStockOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brandsAsync =
        widget.ref.watch(brandsProvider(widget.appCategoryId));

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtros',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Limpiar'),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Sort
                    _SectionTitle(title: 'Ordenar por'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sortOptions.map((opt) {
                        final isSelected = _selectedSort == opt.$1;
                        return ChoiceChip(
                          label: Text(opt.$2),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedSort = opt.$1),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.secondary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Brands
                    _SectionTitle(title: 'Marca'),
                    const SizedBox(height: 8),
                    brandsAsync.when(
                      data: (brands) {
                        if (brands.isEmpty) {
                          return Text(
                            'Selecciona una categoría para ver marcas',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textLight,
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todas'),
                              selected: _selectedBrand == null,
                              onSelected: (_) =>
                                  setState(() => _selectedBrand = null),
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _selectedBrand == null
                                    ? AppColors.secondary
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: _selectedBrand == null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            ...brands.map((brand) {
                              final isSelected = _selectedBrand == brand;
                              return ChoiceChip(
                                label: Text(brand),
                                selected: isSelected,
                                onSelected: (_) =>
                                    setState(() => _selectedBrand = brand),
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppColors.secondary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              );
                            }),
                          ],
                        );
                      },
                      loading: () => const Center(
                          child:
                              CircularProgressIndicator(strokeWidth: 2)),
                      error: (_, _) => const SizedBox(),
                    ),
                    const SizedBox(height: 24),

                    // Stock filter
                    _SectionTitle(title: 'Disponibilidad'),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Solo productos con stock',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      value: _inStockOnly,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _inStockOnly = v),
                    ),
                  ],
                ),
              ),

              // Apply button
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(FilterResult(
                        brand: _selectedBrand,
                        sort: _selectedSort,
                        inStockOnly: _inStockOnly,
                      ));
                      Navigator.pop(context);
                    },
                    child: const Text('Aplicar filtros'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
