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

/// Maps category names to icon + theme-aware colors.
/// - Light mode: gris claro + ícono dorado (estilo higiene/camas/collares)
/// - Dark mode: fondo oscuro + ícono dorado (estilo perro/gato/snacks)
class CategoryStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const CategoryStyle({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  static const _goldIcon = Color(0xFFF7B104);

  // Light mode bg
  static const _lightBg = Color(0xFFF3F4F6);

  // Dark mode bg
  static const _darkBg = Color(0xFF1A1A1A);

  /// Map API icon name to IconData, colors adapt to brightness
  static CategoryStyle forAppCategory(String iconName, [Brightness? brightness]) {
    final iconData = _iconMap[iconName] ?? Icons.shopping_bag_rounded;
    final isDark = brightness == Brightness.dark;
    return CategoryStyle(
      icon: iconData,
      backgroundColor: isDark ? _darkBg : _lightBg,
      iconColor: _goldIcon,
    );
  }

  /// Legacy: map category name to style
  static CategoryStyle forCategory(String name, [Brightness? brightness]) {
    final lower = name.toLowerCase();
    final isDark = brightness == Brightness.dark;

    IconData icon = Icons.shopping_bag_rounded;

    if (lower.contains('aliment') || lower.contains('comida') || lower.contains('food')) {
      icon = Icons.restaurant_rounded;
    } else if (lower.contains('juguete') || lower.contains('toy') || lower.contains('juego')) {
      icon = Icons.sports_baseball_rounded;
    } else if (lower.contains('ropa') || lower.contains('apparel') || lower.contains('vest') || lower.contains('collar')) {
      icon = Icons.checkroom_rounded;
    } else if (lower.contains('salud') || lower.contains('health') || lower.contains('medic') || lower.contains('higiene')) {
      icon = Icons.favorite_rounded;
    } else if (lower.contains('cama') || lower.contains('bed') || lower.contains('casa') || lower.contains('hogar')) {
      icon = Icons.bed_rounded;
    } else if (lower.contains('accesori') || lower.contains('accessor')) {
      icon = Icons.auto_awesome_rounded;
    } else if (lower.contains('arena') || lower.contains('litter') || lower.contains('gato') || lower.contains('cat')) {
      icon = Icons.pets_rounded;
    } else if (lower.contains('transport') || lower.contains('viaje') || lower.contains('travel')) {
      icon = Icons.luggage_rounded;
    } else if (lower.contains('servicio') || lower.contains('service')) {
      icon = Icons.build_rounded;
    }

    return CategoryStyle(
      icon: icon,
      backgroundColor: isDark ? _darkBg : _lightBg,
      iconColor: _goldIcon,
    );
  }

  static const Map<String, IconData> _iconMap = {
    'restaurant': Icons.restaurant_rounded,
    'cookie': Icons.cookie_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'luggage': Icons.luggage_rounded,
    'sports_baseball': Icons.sports_baseball_rounded,
    'pets': Icons.pets_rounded,
    'medical_services': Icons.medical_services_rounded,
    'favorite': Icons.favorite_rounded,
    'bed': Icons.bed_rounded,
    'checkroom': Icons.checkroom_rounded,
    'water_drop': Icons.water_drop_rounded,
    'cleaning_services': Icons.cleaning_services_rounded,
    'auto_awesome': Icons.auto_awesome_rounded,
  };
}
