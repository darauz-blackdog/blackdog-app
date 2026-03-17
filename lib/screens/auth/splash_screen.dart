import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/address_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;
  late AnimationController _exitController;

  late Animation<double> _entryScaleAnimation;
  late Animation<double> _entryFadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _exitScaleAnimation;
  late Animation<double> _exitFadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startFlow();
  }

  void _setupAnimations() {
    // 1. Entry Animation (Logo bounces in and fades)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _entryScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );
    _entryFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // 2. Pulse Animation (Waiting for loads)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Exit Animation (Netflix massive zoom out)
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _exitScaleAnimation = Tween<double>(begin: 1.0, end: 15.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );
    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  Future<void> _startFlow() async {
    // Start entry
    await _entryController.forward();

    // Start pulsing while checking auth and loading data
    _pulseController.repeat(reverse: true);

    // Perform initialization logic
    final nextPage = await _loadData();

    if (!mounted) return;

    _pulseController.stop();

    // Trigger explosive exit zoom
    await _exitController.forward();

    if (!mounted) return;
    context.go(nextPage);
  }

  Future<String> _loadData() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      // Fire GPS in background — don't block navigation
      ref.read(userLocationProvider.future).ignore();

      await Future.wait([
        ref.read(featuredProductsProvider.future),
        ref.read(appCategoriesProvider.future),
        ref.read(cartProvider.future),
        ref.read(addressesProvider.future),
        ref.read(selectedAddressProvider.future),
        ref.read(branchListProvider.future),
        ref.read(homeBannersProvider.future),
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [null, null, null, null, null, null, null],
      );

      // Auto-select nearest address from GPS in background (don't block navigation)
      _autoSelectNearestAddress();

      return '/home';
    } else {
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
      return onboardingDone ? '/login' : '/onboarding';
    }
  }

  Future<void> _autoSelectNearestAddress() async {
    try {
      final selectedAddr = ref.read(selectedAddressProvider).valueOrNull;
      if (selectedAddr != null) return;

      final position = await ref.read(userLocationProvider.future);
      final addresses = ref.read(addressesProvider).valueOrNull ?? [];
      if (addresses.isEmpty || position == null) return;

      Map<String, dynamic>? closest;
      double minDist = double.infinity;
      for (final a in addresses) {
        final map = a as Map<String, dynamic>;
        final lat = (map['latitude'] as num?)?.toDouble();
        final lng = (map['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          final dist = Geolocator.distanceBetween(
            position.latitude, position.longitude, lat, lng,
          );
          if (dist < minDist) {
            minDist = dist;
            closest = map;
          }
        }
      }
      if (closest != null) {
        await ref.read(selectedAddressProvider.notifier).selectAddress(
          SelectedAddress(
            id: closest['id'] as String,
            label: closest['label'] as String? ?? '',
            addressLine: closest['address_line'] as String? ?? '',
            latitude: (closest['latitude'] as num).toDouble(),
            longitude: (closest['longitude'] as num).toDouble(),
          ),
        );
      }
    } catch (_) {
      // GPS not available — silently skip
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
          animation: Listenable.merge([
            _entryController,
            _pulseController,
            _exitController,
          ]),
          builder: (context, child) {
            // Calculate current scale modifiers combined
            final scale =
                _exitController.isAnimating || _exitController.isCompleted
                ? _exitScaleAnimation.value
                : _entryScaleAnimation.value * _pulseAnimation.value;

            final opacity =
                _exitController.isAnimating || _exitController.isCompleted
                ? _exitFadeAnimation.value
                : _entryFadeAnimation.value;

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/Black_Dog_Logo_V.png',
                      width: (MediaQuery.sizeOf(context).width * 0.5).clamp(0, 280).toDouble(),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 16),
                    // We only show the text during the standard entry/pulse, and scale it,
                    // or we could let the exit animation scale everything.
                    Text(
                      'Vive la experiencia Black Dog',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          ),
        ),
      ),
    );
  }
}
