import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/product.dart';
import 'scale_on_tap.dart';

/// Color palette for brand circles based on name hash
const _brandColors = [
  Color(0xFFF7B104),
  Color(0xFF3B82F6),
  Color(0xFF059669),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF0EA5E9),
];

class BrandCircle extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final VoidCallback? onTap;

  const BrandCircle({
    super.key,
    required this.name,
    this.imageUrl,
    this.onTap,
  });

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color get _color => _brandColors[name.hashCode.abs() % _brandColors.length];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaleOnTap(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
              border: Border.all(
                color: isDark
                    ? const Color(0xFF444444)
                    : const Color(0xFFE5E7EB),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _LetterAvatar(
                      initials: _initials,
                      color: _color,
                    ),
                    errorWidget: (_, _, _) => _LetterAvatar(
                      initials: _initials,
                      color: _color,
                    ),
                  )
                : _LetterAvatar(initials: _initials, color: _color),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterAvatar extends StatelessWidget {
  final String initials;
  final Color color;

  const _LetterAvatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class BrandLogosRow extends StatelessWidget {
  final List<HomeSection> brandSections;
  final Function(String brand) onTap;

  const BrandLogosRow({
    super.key,
    required this.brandSections,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (brandSections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Marcas populares',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: brandSections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final section = brandSections[i];
              final brandName = section.filter['brand'] as String? ?? section.title;
              final imageUrl = section.products.isNotEmpty
                  ? section.products.first.imageUrl
                  : null;
              return BrandCircle(
                name: brandName,
                imageUrl: imageUrl,
                onTap: () => onTap(brandName),
              );
            },
          ),
        ),
      ],
    );
  }
}
