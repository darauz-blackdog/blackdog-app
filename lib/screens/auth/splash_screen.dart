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

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final user = ref.read(currentUserProvider);
    if (user != null) {
      // Pre-cargar datos del home en paralelo
      await Future.wait([
        ref.read(featuredProductsProvider.future),
        ref.read(appCategoriesProvider.future),
        ref.read(cartProvider.future),
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () => [null, null, null],
      );
      if (!mounted) return;
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 280,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 16),
            Text(
              'Pet Shop Panamá',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.secondary.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.secondary,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
