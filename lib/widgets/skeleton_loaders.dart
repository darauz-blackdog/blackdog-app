import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../utils/responsive_grid.dart';

/// Base shimmer wrapper that adapts to light/dark theme
class ShimmerWrap extends StatelessWidget {
  final Widget child;
  const ShimmerWrap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: child,
    );
  }
}

/// Skeleton for a single product card in a grid
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
          ),
          // Text area
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 30,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton grid for product listings (catalog, search)
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;
  const ProductGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: responsiveProductGrid(),
        itemCount: itemCount,
        itemBuilder: (_, _) => const ProductCardSkeleton(),
      ),
    );
  }
}

/// Skeleton for horizontal category chips
class CategoryChipsSkeleton extends StatelessWidget {
  const CategoryChipsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, _) => Container(
            width: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for a horizontal product carousel section
class ProductCarouselSkeleton extends StatelessWidget {
  const ProductCarouselSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 18,
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Cards row
            SizedBox(
              height: 220,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) => SizedBox(
                  width: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the home screen category grid (4 boxes)
class HomeCategoriesSkeleton extends StatelessWidget {
  const HomeCategoriesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 18,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: List.generate(
                4,
                (_) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
