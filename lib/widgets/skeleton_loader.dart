import 'package:flutter/material.dart';

/// Shimmer skeleton loading placeholder
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  /// Text-line shaped skeleton
  factory SkeletonLoader.text({Key? key, double width = 120, double height = 14}) =>
      SkeletonLoader(key: key, width: width, height: height, borderRadius: 4);

  /// Circle skeleton (for avatars/icons)
  factory SkeletonLoader.circle({Key? key, double size = 48}) =>
      SkeletonLoader(key: key, width: size, height: size, borderRadius: size / 2);

  /// Card-shaped skeleton
  factory SkeletonLoader.card({Key? key, double height = 80}) =>
      SkeletonLoader(key: key, height: height, borderRadius: 12);

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB);
    final highlightColor = isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF3F4F6);

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_shimmer.value - 0.3).clamp(0.0, 1.0),
                _shimmer.value.clamp(0.0, 1.0),
                (_shimmer.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [baseColor, highlightColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton layout for a checkout summary loading state
class CheckoutSummarySkeleton extends StatelessWidget {
  const CheckoutSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader.text(width: 160, height: 18),
          const SizedBox(height: 20),
          for (var i = 0; i < 3; i++) ...[
            Row(
              children: [
                SkeletonLoader.circle(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader.text(width: 140),
                      const SizedBox(height: 6),
                      SkeletonLoader.text(width: 80, height: 12),
                    ],
                  ),
                ),
                SkeletonLoader.text(width: 50),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonLoader.text(width: 80),
              SkeletonLoader.text(width: 60),
            ],
          ),
        ],
      ),
    );
  }
}
