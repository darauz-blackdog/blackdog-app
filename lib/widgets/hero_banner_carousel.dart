import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PromoBanner {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final IconData decorativeIcon;

  const PromoBanner({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.decorativeIcon,
  });
}

const _banners = [
  PromoBanner(
    title: 'Envío Gratis',
    subtitle: 'en tu primer pedido',
    gradientColors: [Color(0xFFF7B104), Color(0xFFE8890C)],
    decorativeIcon: Icons.local_shipping_rounded,
  ),
  PromoBanner(
    title: '20% OFF',
    subtitle: 'en alimento premium',
    gradientColors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    decorativeIcon: Icons.pets_rounded,
  ),
  PromoBanner(
    title: 'Nuevas sucursales',
    subtitle: 'cerca de ti',
    gradientColors: [Color(0xFF059669), Color(0xFF047857)],
    decorativeIcon: Icons.storefront_rounded,
  ),
];

class HeroBannerCarousel extends StatefulWidget {
  const HeroBannerCarousel({super.key});

  @override
  State<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<HeroBannerCarousel> {
  final _controller = PageController(viewportFraction: 1.0);
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: banner.gradientColors,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative icon
                      Positioned(
                        right: 20,
                        bottom: 10,
                        child: Icon(
                          banner.decorativeIcon,
                          size: 100,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      // Text content
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              banner.title,
                              style: GoogleFonts.montserrat(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              banner.subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final isActive = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive
                    ? const Color(0xFFF7B104)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.15),
              ),
            );
          }),
        ),
      ],
    );
  }
}
