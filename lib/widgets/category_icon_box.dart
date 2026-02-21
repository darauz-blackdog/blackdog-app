import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryIconBox extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const CategoryIconBox({
    super.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  });

  @override
  State<CategoryIconBox> createState() => _CategoryIconBoxState();
}

class _CategoryIconBoxState extends State<CategoryIconBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 32),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Maps category names to icon + colors.
class CategoryStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const CategoryStyle({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  static CategoryStyle forCategory(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('aliment') || lower.contains('comida') || lower.contains('food')) {
      return const CategoryStyle(
        icon: Icons.restaurant_rounded,
        backgroundColor: Color(0xFFFEF3C7), // warm yellow
        iconColor: Color(0xFFF59E0B),
      );
    }
    if (lower.contains('juguete') || lower.contains('toy') || lower.contains('juego')) {
      return const CategoryStyle(
        icon: Icons.sports_baseball_rounded,
        backgroundColor: Color(0xFFDBEAFE), // light blue
        iconColor: Color(0xFF3B82F6),
      );
    }
    if (lower.contains('ropa') || lower.contains('apparel') || lower.contains('vest') || lower.contains('collar')) {
      return const CategoryStyle(
        icon: Icons.checkroom_rounded,
        backgroundColor: Color(0xFFD1FAE5), // light green
        iconColor: Color(0xFF10B981),
      );
    }
    if (lower.contains('salud') || lower.contains('health') || lower.contains('medic') || lower.contains('higiene')) {
      return const CategoryStyle(
        icon: Icons.favorite_rounded,
        backgroundColor: Color(0xFFEDE9FE), // light purple
        iconColor: Color(0xFF8B5CF6),
      );
    }
    if (lower.contains('cama') || lower.contains('bed') || lower.contains('casa') || lower.contains('hogar')) {
      return const CategoryStyle(
        icon: Icons.bed_rounded,
        backgroundColor: Color(0xFFFEE2E2), // light red
        iconColor: Color(0xFFEF4444),
      );
    }
    if (lower.contains('accesori') || lower.contains('accessor')) {
      return const CategoryStyle(
        icon: Icons.auto_awesome_rounded,
        backgroundColor: Color(0xFFFCE7F3), // light pink
        iconColor: Color(0xFFEC4899),
      );
    }
    if (lower.contains('arena') || lower.contains('litter') || lower.contains('gato') || lower.contains('cat')) {
      return const CategoryStyle(
        icon: Icons.pets_rounded,
        backgroundColor: Color(0xFFE0F2FE), // sky blue
        iconColor: Color(0xFF0EA5E9),
      );
    }
    if (lower.contains('transport') || lower.contains('viaje') || lower.contains('travel')) {
      return const CategoryStyle(
        icon: Icons.luggage_rounded,
        backgroundColor: Color(0xFFFEF9C3), // light lime
        iconColor: Color(0xFFCA8A04),
      );
    }
    // Default
    return const CategoryStyle(
      icon: Icons.shopping_bag_rounded,
      backgroundColor: Color(0xFFF3F4F6),
      iconColor: Color(0xFF6B7280),
    );
  }
}
