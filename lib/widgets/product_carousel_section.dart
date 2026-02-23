import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import 'product_card.dart';

class ProductCarouselSection extends StatelessWidget {
  final String title;
  final List<Product> products;
  final VoidCallback onViewAll;
  final Function(Product) onTap;
  final Function(Product) onAddToCart;

  const ProductCarouselSection({
    super.key,
    required this.title,
    required this.products,
    required this.onViewAll,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver todo',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Horizontal product list
        SizedBox(
          height: 200,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 130,
                child: ProductCard(
                  product: product,
                  compact: true,
                  onTap: () => onTap(product),
                  onAddToCart: () => onAddToCart(product),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
