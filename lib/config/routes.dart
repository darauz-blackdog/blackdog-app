import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/orders/order_tracking_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../models/order.dart';
import '../screens/catalog/catalog_screen.dart';
import '../screens/catalog/product_detail_screen.dart';
import '../screens/catalog/search_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/checkout/checkout_screen.dart';
import '../screens/checkout/order_confirmation_screen.dart';
import '../screens/checkout/payment_status_screen.dart';
import '../screens/checkout/tilopay_payment_screen.dart';
import '../screens/checkout/yappy_payment_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/branches/branches_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/add_address_screen.dart';
import '../screens/profile/edit_address_screen.dart';
import '../screens/profile/addresses_screen.dart';
import '../screens/profile/delete_account_screen.dart';
import '../screens/profile/change_password_screen.dart';
import '../screens/profile/about_screen.dart';
import '../screens/profile/legal_screen.dart';
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
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/' ||
          state.matchedLocation == '/onboarding';

      // While auth is resolving, stay on splash — don't redirect
      if (isLoading && state.matchedLocation == '/') {
        return null;
      }

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
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fadeThrough(state, const OnboardingScreen()),
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
            path: '/favorites',
            pageBuilder: (context, state) => _fadeThrough(state, const FavoritesScreen()),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (context, state) => _sharedAxisY(state, const NotificationsScreen()),
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
                routes: [
                  GoRoute(
                    path: 'tracking',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return _sharedAxisY(state, OrderTrackingScreen(orderId: id));
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => _fadeThrough(state, const ProfileScreen()),
            routes: [
              GoRoute(
                path: 'edit',
                pageBuilder: (context, state) => _sharedAxisY(state, const EditProfileScreen()),
              ),
              GoRoute(
                path: 'addresses',
                pageBuilder: (context, state) => _sharedAxisY(state, const AddressesScreen()),
                routes: [
                  GoRoute(
                    path: 'add',
                    pageBuilder: (context, state) => _sharedAxisY(state, const AddAddressScreen()),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    pageBuilder: (context, state) {
                      final addr = state.extra as Map<String, dynamic>;
                      return _sharedAxisY(state, EditAddressScreen(address: addr));
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'change-password',
                pageBuilder: (context, state) => _sharedAxisY(state, const ChangePasswordScreen()),
              ),
              GoRoute(
                path: 'about',
                pageBuilder: (context, state) => _sharedAxisY(state, const AboutScreen()),
              ),
              GoRoute(
                path: 'privacy',
                pageBuilder: (context, state) => _sharedAxisY(state, const LegalScreen(type: LegalType.privacy)),
              ),
              GoRoute(
                path: 'terms',
                pageBuilder: (context, state) => _sharedAxisY(state, const LegalScreen(type: LegalType.terms)),
              ),
              GoRoute(
                path: 'delete-account',
                pageBuilder: (context, state) => _sharedAxisY(state, const DeleteAccountScreen()),
              ),
            ],
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
      ),
      GoRoute(
        path: '/checkout',
        pageBuilder: (context, state) => _sharedAxisY(state, const CheckoutScreen()),
        routes: [
          GoRoute(
            path: 'add-address',
            pageBuilder: (context, state) => _sharedAxisY(state, const AddAddressScreen()),
          ),
        ],
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
        path: '/payment/:orderId',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _sharedAxisY(
            state,
            PaymentStatusScreen(
              orderId: state.pathParameters['orderId']!,
              paymentUrl: extra?['payment_url'] as String?,
              paymentMethod: extra?['payment_method'] as String?,
            ),
          );
        },
        routes: [
          GoRoute(
            path: 'tilopay',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return _sharedAxisY(
                state,
                TilopayPaymentScreen(
                  orderId: state.pathParameters['orderId']!,
                  paymentUrl: extra?['payment_url'] as String? ?? '',
                  orderName: extra?['order_name'] as String?,
                  amount: (extra?['amount'] as num?)?.toDouble(),
                ),
              );
            },
          ),
          GoRoute(
            path: 'yappy',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return _sharedAxisY(
                state,
                YappyPaymentScreen(
                  orderId: state.pathParameters['orderId']!,
                  orderName: extra?['order_name'] as String?,
                  amount: (extra?['amount'] as num?)?.toDouble(),
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
});
