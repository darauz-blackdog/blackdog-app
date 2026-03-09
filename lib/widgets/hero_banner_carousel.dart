import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';

Color _hexToColor(String hex, Color fallback) {
  final clean = hex.replaceFirst('#', '');
  if (clean.length != 6) return fallback;
  final value = int.tryParse(clean, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

class HeroBannerCarousel extends StatefulWidget {
  final List<HomeBanner> banners;

  const HeroBannerCarousel({super.key, required this.banners});

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
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(HeroBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _currentPage = 0;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onBannerTap(HomeBanner banner) {
    switch (banner.linkType) {
      case 'product':
        if (banner.linkValue != null) {
          context.push('/product/${banner.linkValue}');
        }
      case 'category':
        if (banner.linkValue != null) {
          context.go('/catalog?app_category_id=${banner.linkValue}');
        }
      case 'brand':
        if (banner.linkValue != null) {
          final encoded = Uri.encodeComponent(banner.linkValue!);
          context.go('/catalog?brand=$encoded');
        }
      case 'url':
        if (banner.linkValue != null) {
          final uri = Uri.tryParse(banner.linkValue!);
          if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    final bannerHeight = MediaQuery.sizeOf(context).width * 0.4;
    final clampedHeight = bannerHeight.clamp(140.0, 220.0);
    return Column(
      children: [
        SizedBox(
          height: clampedHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: banner.linkType != 'none'
                      ? () => _onBannerTap(banner)
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: banner.imageUrl != null
                        ? _ImageBanner(banner: banner, height: clampedHeight)
                        : _GradientBanner(banner: banner),
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
          children: List.generate(widget.banners.length, (i) {
            final isActive = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive
                    ? AppColors.primary
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

class _ImageBanner extends StatelessWidget {
  final HomeBanner banner;
  final double height;

  const _ImageBanner({required this.banner, required this.height});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: banner.imageUrl!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => _GradientBanner(banner: banner),
    );
  }
}

class _GradientBanner extends StatelessWidget {
  final HomeBanner banner;

  const _GradientBanner({required this.banner});

  @override
  Widget build(BuildContext context) {
    final start = banner.gradientStart != null
        ? _hexToColor(banner.gradientStart!, AppColors.primary)
        : AppColors.primary;
    final end = banner.gradientEnd != null
        ? _hexToColor(banner.gradientEnd!, start)
        : start;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      child: Padding(
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
            if (banner.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                banner.subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
