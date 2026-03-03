import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryIconBox extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool large;
  final int? productCount;

  const CategoryIconBox({
    super.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
    this.large = false,
    this.productCount,
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
        child: widget.large ? _buildLarge(context) : _buildCompact(context),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return SizedBox(
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
    );
  }

  Widget _buildLarge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF444444) : const Color(0xFFE5E7EB),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.productCount != null) ...[
            const SizedBox(height: 2),
            Text(
              '${widget.productCount} productos',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
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
        backgroundColor: _darkBg,
        iconColor: _goldIcon,
      );
    }
    return _defaultStyle;
  }

  // Brand palette only: yellow #F7B104, dark #1A1A1A, neutrals
  static const _goldBg = Color(0xFFFFF3D0);     // light yellow bg
  static const _goldIcon = Color(0xFFF7B104);    // primary yellow
  static const _darkBg = Color(0xFF1A1A1A);      // near-black bg
  static const _darkIcon = Color(0xFF1A1A1A);    // near-black icon
  static const _warmBg = Color(0xFFFEF3C7);      // warm cream bg
  static const _neutralBg = Color(0xFFF3F4F6);   // light gray bg

  static const _defaultStyle = CategoryStyle(
    icon: Icons.shopping_bag_rounded,
    backgroundColor: _neutralBg,
    iconColor: _goldIcon,
  );

  static final Map<String, CategoryStyle> _iconStyles = {
    // Variante 1: fondo amarillo claro + ícono negro
    'restaurant': const CategoryStyle(
      icon: Icons.restaurant_rounded,
      backgroundColor: _goldBg,
      iconColor: _darkIcon,
    ),
    'cookie': const CategoryStyle(
      icon: Icons.cookie_rounded,
      backgroundColor: _warmBg,
      iconColor: _darkIcon,
    ),
    'fitness_center': const CategoryStyle(
      icon: Icons.fitness_center_rounded,
      backgroundColor: _goldBg,
      iconColor: _darkIcon,
    ),
    'luggage': const CategoryStyle(
      icon: Icons.luggage_rounded,
      backgroundColor: _warmBg,
      iconColor: _darkIcon,
    ),
    // Variante 2: fondo negro + ícono amarillo
    'sports_baseball': const CategoryStyle(
      icon: Icons.sports_baseball_rounded,
      backgroundColor: _darkBg,
      iconColor: _goldIcon,
    ),
    'pets': const CategoryStyle(
      icon: Icons.pets_rounded,
      backgroundColor: _darkBg,
      iconColor: _goldIcon,
    ),
    'medical_services': const CategoryStyle(
      icon: Icons.medical_services_rounded,
      backgroundColor: _darkBg,
      iconColor: _goldIcon,
    ),
    // Variante 3: fondo gris claro + ícono amarillo dorado
    'favorite': const CategoryStyle(
      icon: Icons.favorite_rounded,
      backgroundColor: _neutralBg,
      iconColor: _goldIcon,
    ),
    'bed': const CategoryStyle(
      icon: Icons.bed_rounded,
      backgroundColor: _neutralBg,
      iconColor: _goldIcon,
    ),
    'checkroom': const CategoryStyle(
      icon: Icons.checkroom_rounded,
      backgroundColor: _neutralBg,
      iconColor: _goldIcon,
    ),
    'water_drop': const CategoryStyle(
      icon: Icons.water_drop_rounded,
      backgroundColor: _goldBg,
      iconColor: _darkIcon,
    ),
    'cleaning_services': const CategoryStyle(
      icon: Icons.cleaning_services_rounded,
      backgroundColor: _warmBg,
      iconColor: _darkIcon,
    ),
    'auto_awesome': const CategoryStyle(
      icon: Icons.auto_awesome_rounded,
      backgroundColor: _darkBg,
      iconColor: _goldIcon,
    ),
  };
}
