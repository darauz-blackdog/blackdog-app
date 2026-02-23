import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../models/order.dart';
import '../screens/catalog/catalog_screen.dart';
import '../screens/catalog/product_detail_screen.dart';
import '../screens/catalog/search_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/checkout/checkout_screen.dart';
import '../screens/checkout/order_confirmation_screen.dart';
import '../screens/branches/branches_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/common/main_shell.dart';
import '../providers/auth_provider.dart';

// M3 fade-through transition for smooth page changes
CustomTransitionPage<void> _fadeThrough(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeIn = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final fadeOut = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: fadeIn,
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(fadeOut),
          child: child,
        ),
      );
    },
  );
}

// M3 shared axis (vertical) transition for detail screens
CustomTransitionPage<void> _sharedAxisY(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fadeThrough(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadeThrough(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _sharedAxisY(state, const RegisterScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => _fadeThrough(state, const HomeScreen()),
          ),
          GoRoute(
            path: '/catalog',
            pageBuilder: (context, state) => _fadeThrough(
              state,
              CatalogScreen(
                categoryId: state.uri.queryParameters['category_id'] != null
                    ? int.parse(state.uri.queryParameters['category_id']!)
                    : null,
                appCategoryId: state.uri.queryParameters['app_category_id'] != null
                    ? int.parse(state.uri.queryParameters['app_category_id']!)
                    : null,
                brand: state.uri.queryParameters['brand'],
              ),
            ),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => _fadeThrough(state, const SearchScreen()),
          ),
          GoRoute(
            path: '/cart',
            pageBuilder: (context, state) => _sharedAxisY(state, const CartScreen()),
          ),
          GoRoute(
            path: '/branches',
            pageBuilder: (context, state) => _fadeThrough(state, const BranchesScreen()),
          ),
          GoRoute(
            path: '/orders',
            pageBuilder: (context, state) => _fadeThrough(state, const OrdersScreen()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final extra = state.extra as Order?;
                  return _sharedAxisY(
                    state,
                    OrderDetailScreen(orderId: id, extraOrder: extra),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => _fadeThrough(state, const ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/checkout',
        pageBuilder: (context, state) => _sharedAxisY(state, const CheckoutScreen()),
      ),
      GoRoute(
        path: '/order-confirmation/:id',
        pageBuilder: (context, state) => _fadeThrough(
          state,
          OrderConfirmationScreen(
            orderId: state.pathParameters['id']!,
            orderData: state.extra as Map<String, dynamic>?,
          ),
        ),
      ),
      GoRoute(
        path: '/product/:id',
        pageBuilder: (context, state) => _sharedAxisY(
          state,
          ProductDetailScreen(
            productId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
    ],
  );
});
