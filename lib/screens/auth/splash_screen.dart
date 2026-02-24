import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
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
      duration: const Duration(milliseconds: 600),
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
    // Minimum wait time for aesthetic purposes
    await Future.delayed(const Duration(milliseconds: 1000));

    final user = ref.read(currentUserProvider);
    if (user != null) {
      await Future.wait([
        ref.read(featuredProductsProvider.future),
        ref.read(appCategoriesProvider.future),
        ref.read(cartProvider.future),
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [null, null, null],
      );
      return '/home';
    } else {
      return '/login';
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
      backgroundColor: AppColors.primary,
      body: Center(
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
                      width: 250,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 16),
                    // We only show the text during the standard entry/pulse, and scale it,
                    // or we could let the exit animation scale everything.
                    Text(
                      'Pet Shop Panamá',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.secondary.withValues(alpha: 0.7),
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
    );
  }
}
