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
/// Now supports both legacy category names and new app_category icon names from the API.
class CategoryStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const CategoryStyle({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  /// Map API icon name (Material icon string) to IconData + colors
  static CategoryStyle forAppCategory(String iconName) {
    return _iconStyles[iconName] ?? _defaultStyle;
  }

  /// Legacy: map category name to style (used by old categoriesProvider)
  static CategoryStyle forCategory(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('aliment') || lower.contains('comida') || lower.contains('food')) {
      return _iconStyles['restaurant']!;
    }
    if (lower.contains('juguete') || lower.contains('toy') || lower.contains('juego')) {
      return _iconStyles['sports_baseball']!;
    }
    if (lower.contains('ropa') || lower.contains('apparel') || lower.contains('vest') || lower.contains('collar')) {
      return _iconStyles['checkroom']!;
    }
    if (lower.contains('salud') || lower.contains('health') || lower.contains('medic') || lower.contains('higiene')) {
      return _iconStyles['favorite']!;
    }
    if (lower.contains('cama') || lower.contains('bed') || lower.contains('casa') || lower.contains('hogar')) {
      return _iconStyles['bed']!;
    }
    if (lower.contains('accesori') || lower.contains('accessor')) {
      return _iconStyles['auto_awesome']!;
    }
    if (lower.contains('arena') || lower.contains('litter') || lower.contains('gato') || lower.contains('cat')) {
      return _iconStyles['pets']!;
    }
    if (lower.contains('transport') || lower.contains('viaje') || lower.contains('travel')) {
      return _iconStyles['luggage']!;
    }
    if (lower.contains('servicio') || lower.contains('service')) {
      return const CategoryStyle(
        icon: Icons.build_rounded,
        backgroundColor: Color(0xFFE0F2FE),
        iconColor: Color(0xFF0EA5E9),
      );
    }
    return _defaultStyle;
  }

  static const _defaultStyle = CategoryStyle(
    icon: Icons.shopping_bag_rounded,
    backgroundColor: Color(0xFFF3F4F6),
    iconColor: Color(0xFF6B7280),
  );

  static final Map<String, CategoryStyle> _iconStyles = {
    'restaurant': const CategoryStyle(
      icon: Icons.restaurant_rounded,
      backgroundColor: Color(0xFFFEF3C7),
      iconColor: Color(0xFFF59E0B),
    ),
    'cookie': const CategoryStyle(
      icon: Icons.cookie_rounded,
      backgroundColor: Color(0xFFFED7AA),
      iconColor: Color(0xFFEA580C),
    ),
    'sports_baseball': const CategoryStyle(
      icon: Icons.sports_baseball_rounded,
      backgroundColor: Color(0xFFDBEAFE),
      iconColor: Color(0xFF3B82F6),
    ),
    'favorite': const CategoryStyle(
      icon: Icons.favorite_rounded,
      backgroundColor: Color(0xFFEDE9FE),
      iconColor: Color(0xFF8B5CF6),
    ),
    'bed': const CategoryStyle(
      icon: Icons.bed_rounded,
      backgroundColor: Color(0xFFFEE2E2),
      iconColor: Color(0xFFEF4444),
    ),
    'checkroom': const CategoryStyle(
      icon: Icons.checkroom_rounded,
      backgroundColor: Color(0xFFD1FAE5),
      iconColor: Color(0xFF10B981),
    ),
    'water_drop': const CategoryStyle(
      icon: Icons.water_drop_rounded,
      backgroundColor: Color(0xFFCFFAFE),
      iconColor: Color(0xFF0891B2),
    ),
    'pets': const CategoryStyle(
      icon: Icons.pets_rounded,
      backgroundColor: Color(0xFFE0F2FE),
      iconColor: Color(0xFF0EA5E9),
    ),
    'fitness_center': const CategoryStyle(
      icon: Icons.fitness_center_rounded,
      backgroundColor: Color(0xFFD1FAE5),
      iconColor: Color(0xFF059669),
    ),
    'luggage': const CategoryStyle(
      icon: Icons.luggage_rounded,
      backgroundColor: Color(0xFFFEF9C3),
      iconColor: Color(0xFFCA8A04),
    ),
    'cleaning_services': const CategoryStyle(
      icon: Icons.cleaning_services_rounded,
      backgroundColor: Color(0xFFE0E7FF),
      iconColor: Color(0xFF6366F1),
    ),
    'medical_services': const CategoryStyle(
      icon: Icons.medical_services_rounded,
      backgroundColor: Color(0xFFFCE7F3),
      iconColor: Color(0xFFDB2777),
    ),
    'auto_awesome': const CategoryStyle(
      icon: Icons.auto_awesome_rounded,
      backgroundColor: Color(0xFFFCE7F3),
      iconColor: Color(0xFFEC4899),
    ),
  };
}
