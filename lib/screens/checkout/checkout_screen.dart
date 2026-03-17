import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/branch.dart';
import '../../models/cart.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_branch_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/service_providers.dart';
import '../../utils/error_utils.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/step_indicator.dart';

final _addressesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getAddresses();
  return data.cast<Map<String, dynamic>>();
});

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _step = 0; // 0=delivery, 1=payment, 2=summary
  String _deliveryType = 'pickup';
  int? _selectedBranchId;
  String? _selectedAddressId;
  String _paymentMethod = 'tilopay';
  String? _notes;
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromProviders());
  }

  // Inline WebView state for Tilopay
  bool _showInlineWebView = false;
  WebViewController? _webViewController;
  bool _webViewLoading = true;
  String? _currentOrderId;

  void _initFromProviders() {
    if (_initialized) return;
    _initialized = true;

    final bestDelivery = ref.read(bestDeliveryBranchProvider);
    final address = ref.read(selectedAddressProvider).valueOrNull;

    if (bestDelivery != null && address != null) {
      // Delivery available — auto-assign best branch
      _deliveryType = 'delivery';
      _selectedBranchId = bestDelivery.branch.id;
      _selectedAddressId = address.id;
    } else {
      // Pickup only — select best branch by stock
      _deliveryType = 'pickup';
      final ranked = ref.read(rankedBranchesProvider).valueOrNull;
      if (ranked != null && ranked.isNotEmpty) {
        // First pickup-enabled branch with full stock (already sorted by stock+distance)
        final best = ranked.where((r) => r.branch.isPickupEnabled && r.hasFullStock).firstOrNull;
        if (best != null) _selectedBranchId = best.branch.id;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // WebView check FIRST — cart is already empty after order creation
    if (_showInlineWebView) {
      return _buildInlineWebViewScreen();
    }

    final cart = ref.watch(cartProvider).valueOrNull;

    if (cart == null || cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tu carrito está vacío',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Agrega productos antes de continuar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.go('/catalog'),
                  icon: const Icon(Icons.storefront_rounded),
                  label: const Text('Ver productos'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _step > 0
              ? () => setState(() => _step--)
              : () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          StepIndicator(
            currentStep: _step,
            labels: const ['Entrega', 'Pago', 'Resumen'],
          ),
          Expanded(
            child: ResponsiveCenter(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCurrentStep(cart),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineWebViewScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago seguro'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() => _showInlineWebView = false);
            // Go to order detail since order is already created
            if (_currentOrderId != null) {
              context.go('/orders/$_currentOrderId');
            }
          },
        ),
      ),
      body: Stack(
        children: [
          if (_webViewController != null)
            WebViewWidget(controller: _webViewController!),
          if (_webViewLoading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return 'Método de entrega';
      case 1:
        return 'Método de pago';
      case 2:
        return 'Resumen del pedido';
      default:
        return 'Checkout';
    }
  }

  Widget _buildCurrentStep(Cart cart) {
    switch (_step) {
      case 0:
        return _DeliveryStep(
          key: const ValueKey('delivery'),
          deliveryType: _deliveryType,
          selectedBranchId: _selectedBranchId,
          selectedAddressId: _selectedAddressId,
          onDeliveryTypeChanged: (v) => setState(() {
            _deliveryType = v;
            if (v == 'delivery') {
              // Auto-assign best delivery branch
              _selectedAddressId = ref.read(selectedAddressProvider).valueOrNull?.id;
              final best = ref.read(bestDeliveryBranchProvider);
              _selectedBranchId = best?.branch.id;
            } else {
              // Pickup — auto-select best pickup branch by stock
              _selectedAddressId = null;
              final ranked = ref.read(rankedBranchesProvider).valueOrNull ?? [];
              final best = ranked.where((r) => r.branch.isPickupEnabled && r.hasFullStock).firstOrNull;
              _selectedBranchId = best?.branch.id;
            }
          }),
          onBranchSelected: (id) => setState(() => _selectedBranchId = id),
          onAddressSelected: (id) {
            setState(() => _selectedAddressId = id);
            // Persist selection globally
            final addresses = ref.read(_addressesProvider).valueOrNull ?? [];
            final addr = addresses.where((a) => a['id'] == id).firstOrNull;
            if (addr != null) {
              ref.read(selectedAddressProvider.notifier).selectAddress(
                SelectedAddress(
                  id: addr['id'] as String,
                  label: addr['label'] as String? ?? '',
                  addressLine: addr['address_line'] as String? ?? '',
                  latitude: (addr['latitude'] as num?)?.toDouble() ?? 0,
                  longitude: (addr['longitude'] as num?)?.toDouble() ?? 0,
                ),
              );
            }
          },
          onNext: _canProceedDelivery ? () => setState(() => _step = 1) : null,
        );
      case 1:
        return _PaymentStep(
          key: const ValueKey('payment'),
          paymentMethod: _paymentMethod,
          deliveryType: _deliveryType,
          onPaymentMethodChanged: (v) => setState(() => _paymentMethod = v),
          onNext: () => setState(() => _step = 2),
        );
      case 2:
        return _SummaryStep(
          key: const ValueKey('summary'),
          cart: cart,
          deliveryType: _deliveryType,
          selectedBranchId: _selectedBranchId,
          selectedAddressId: _selectedAddressId,
          paymentMethod: _paymentMethod,
          notes: _notes,
          isSubmitting: _isSubmitting,
          onNotesChanged: (v) => _notes = v,
          onConfirm: _submitOrder,
          onAddressChanged: _deliveryType == 'delivery' ? (id) {
            setState(() => _selectedAddressId = id);
            // Persist globally
            final addresses = ref.read(_addressesProvider).valueOrNull ?? [];
            final addr = addresses.where((a) => a['id'] == id).firstOrNull;
            if (addr != null) {
              ref.read(selectedAddressProvider.notifier).selectAddress(
                SelectedAddress(
                  id: addr['id'] as String,
                  label: addr['label'] as String? ?? '',
                  addressLine: addr['address_line'] as String? ?? '',
                  latitude: (addr['latitude'] as num?)?.toDouble() ?? 0,
                  longitude: (addr['longitude'] as num?)?.toDouble() ?? 0,
                ),
              );
            }
          } : null,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  bool get _canProceedDelivery {
    if (_deliveryType == 'pickup') return _selectedBranchId != null;
    return _selectedBranchId != null && _selectedAddressId != null;
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.createOrder(
        deliveryType: _deliveryType,
        branchId: _selectedBranchId!,
        paymentMethod: _paymentMethod,
        addressId: _selectedAddressId,
        notes: _notes,
      );

      // Refresh cart (it's been converted)
      ref.read(cartProvider.notifier).refresh();

      if (!mounted) return;

      final orderId = result['order']?['id'] as String? ?? '';
      final paymentUrl = result['payment_url'] as String?;
      final orderName = result['odoo_order_name'] as String? ??
          result['order']?['payment_reference'] as String?;
      final total = (result['order']?['total'] as num?)?.toDouble();

      _currentOrderId = orderId;

      // For online payment methods, go directly to payment — no intermediate screen.
      // Order confirmation is shown only after successful payment (or for in_store).
      if (_paymentMethod == 'tilopay' || _paymentMethod == 'yappy') {
        context.go(
          '/payment/$orderId',
          extra: {
            'payment_method': _paymentMethod,
            'amount': total ?? 0.0,
            'order_number': orderName,
          },
        );
      } else {
        // in_store: show confirmation immediately
        if (result is Map<String, dynamic> && !result.containsKey('payment_method')) {
          result['payment_method'] = _paymentMethod;
        }
        context.go('/order-confirmation/$orderId', extra: result);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        final message = friendlyError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  void _openInlineWebView(String paymentUrl, String orderId, String? orderName) {
    if (kIsWeb) {
      launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
      context.go('/orders/$orderId');
      return;
    }

    // Only load whitelisted payment domains
    final uri = Uri.parse(paymentUrl);
    const allowedDomains = ['tilopay.com', 'tilopay.cr', 'blackdogpanama.com'];
    if (!allowedDomains.any((d) => uri.host == d || uri.host.endsWith('.$d'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dominio de pago no permitido'), duration: Duration(seconds: 3)),
      );
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _webViewLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _webViewLoading = false);
          },
          onNavigationRequest: (request) {
            // Whitelist: only allow Tilopay domains
            final navUri = Uri.tryParse(request.url);
            if (navUri != null) {
              final host = navUri.host;
              if (!allowedDomains.any((d) => host == d || host.endsWith('.$d'))) {
                return NavigationDecision.prevent;
              }
            }

            final url = request.url.toLowerCase();

            // Success callbacks
            if (url.contains('payment/success') ||
                url.contains('payment/callback') ||
                url.contains('status=approved') ||
                (url.contains('tilopay/result') && url.contains('status=paid'))) {
              setState(() => _showInlineWebView = false);
              context.go('/order-confirmation/$orderId');
              return NavigationDecision.prevent;
            }

            // Failure callbacks
            if (url.contains('payment/cancel') ||
                url.contains('payment/failed') ||
                url.contains('status=declined') ||
                (url.contains('tilopay/result') && url.contains('status=failed'))) {
              setState(() => _showInlineWebView = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('El pago fue rechazado. Intenta de nuevo.'), duration: Duration(seconds: 3)),
              );
              context.go('/orders/$orderId');
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(uri);

    setState(() {
      _webViewController = controller;
      _showInlineWebView = true;
      _webViewLoading = true;
      _isSubmitting = false;
    });
  }
}

// ── Step 1: Delivery ──────────────────────────────────────────────

class _DeliveryStep extends ConsumerWidget {
  final String deliveryType;
  final int? selectedBranchId;
  final String? selectedAddressId;
  final ValueChanged<String> onDeliveryTypeChanged;
  final ValueChanged<int> onBranchSelected;
  final ValueChanged<String> onAddressSelected;
  final VoidCallback? onNext;

  const _DeliveryStep({
    super.key,
    required this.deliveryType,
    required this.selectedBranchId,
    required this.selectedAddressId,
    required this.onDeliveryTypeChanged,
    required this.onBranchSelected,
    required this.onAddressSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankedAsync = ref.watch(rankedBranchesProvider);
    final canDeliver = ref.watch(deliveryAvailableProvider);
    final bestDelivery = ref.watch(bestDeliveryBranchProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(Responsive.padding(context)),
            children: [
              // ── Delivery option ──
              _RadioCard(
                title: 'Delivery via ASAP',
                subtitle: canDeliver
                    ? 'El envío lo coordina y cobra ASAP'
                    : 'No hay sucursales con delivery en tu zona',
                icon: Icons.delivery_dining_outlined,
                selected: deliveryType == 'delivery',
                onTap: canDeliver
                    ? () => onDeliveryTypeChanged('delivery')
                    : () {},
                compact: !canDeliver,
              ),
              const SizedBox(height: 12),
              _RadioCard(
                title: 'Recoger en tienda',
                subtitle: 'Sin costo de delivery',
                icon: Icons.store_outlined,
                selected: deliveryType == 'pickup',
                onTap: () => onDeliveryTypeChanged('pickup'),
              ),

              // ── Delivery: address + auto-assigned branch ──
              if (deliveryType == 'delivery') ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dirección de entrega',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await context.push<bool>('/checkout/add-address');
                        if (result == true) {
                          ref.invalidate(_addressesProvider);
                          ref.invalidate(addressesProvider);
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildAddressList(context, ref),

                // Auto-assigned delivery branch info
                if (bestDelivery != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Sucursal asignada',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _BranchStockCard(
                    ranked: bestDelivery,
                    selected: true,
                    onTap: null,
                  ),
                  if (!bestDelivery.hasFullStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Productos sin stock: ${bestDelivery.missingProducts.join(", ")}',
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],

              // ── Pickup: user selects branch ──
              if (deliveryType == 'pickup') ...[
                const SizedBox(height: 24),
                Text(
                  'Selecciona sucursal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                rankedAsync.when(
                  data: (list) {
                    final pickupBranches = list
                        .where((r) => r.branch.isPickupEnabled && r.hasFullStock)
                        .toList();

                    if (pickupBranches.isEmpty) {
                      return const Text('No hay sucursales con stock completo para tu pedido');
                    }

                    return Column(
                      children: pickupBranches.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BranchStockCard(
                          ranked: r,
                          selected: selectedBranchId == r.branch.id,
                          onTap: () => onBranchSelected(r.branch.id),
                        ),
                      )).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => const Text('Error cargando sucursales'),
                ),
              ],
            ],
          ),
        ),
        _BottomButton(label: 'Continuar', onPressed: onNext),
      ],
    );
  }

  Widget _buildAddressList(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(_addressesProvider);

    return addresses.when(
      data: (list) {
        if (list.isEmpty) {
          return Container(
            padding: EdgeInsets.all(Responsive.padding(context)),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('No hay direcciones guardadas.\nAgrega una nueva.'),
            ),
          );
        }
        // Auto-select first address if none selected
        if (selectedAddressId == null && list.isNotEmpty) {
          final defaultAddr = list.firstWhere(
            (a) => a['is_default'] == true,
            orElse: () => list.first,
          );
          final id = defaultAddr['id'] as String;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onAddressSelected(id);
          });
        }
        return Column(
          children: list.map((addr) {
            final id = addr['id'] as String;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RadioCard(
                title: addr['label'] as String? ?? 'Dirección',
                subtitle: addr['address_line'] as String? ?? '',
                icon: Icons.home_outlined,
                selected: selectedAddressId == id,
                onTap: () => onAddressSelected(id),
                compact: true,
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => const Text('Error cargando direcciones'),
    );
  }
}

/// Card showing branch name, address, distance, and stock status.
class _BranchStockCard extends StatelessWidget {
  final RankedBranch ranked;
  final bool selected;
  final VoidCallback? onTap;

  const _BranchStockCard({
    required this.ranked,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = ranked.branch;
    final hasStock = ranked.hasFullStock;
    final distText = ranked.distanceKm < 100
        ? '${ranked.distanceKm.toStringAsFixed(1)} km'
        : '';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.location_on_outlined,
                size: 20,
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (b.address != null)
                    Text(
                      b.address!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (distText.isNotEmpty)
                  Text(
                    distText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasStock
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasStock
                        ? 'Stock completo'
                        : '${ranked.itemsInStock}/${ranked.totalItems} items',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: hasStock ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Payment Method ───────────────────────────────────────

class _PaymentStep extends StatelessWidget {
  final String paymentMethod;
  final String deliveryType;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onNext;

  const _PaymentStep({
    super.key,
    required this.paymentMethod,
    required this.deliveryType,
    required this.onPaymentMethodChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(Responsive.padding(context)),
            children: [
              Text(
                'Selecciona cómo deseas pagar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _RadioCard(
                title: 'Tarjeta de crédito / débito',
                subtitle: 'Pago seguro con Tilopay',
                icon: Icons.credit_card_rounded,
                selected: paymentMethod == 'tilopay',
                onTap: () => onPaymentMethodChanged('tilopay'),
              ),
              const SizedBox(height: 12),
              _RadioCard(
                title: 'Yappy',
                subtitle: 'Paga rápido con tu número de teléfono',
                icon: Icons.phone_android_rounded,
                selected: paymentMethod == 'yappy',
                onTap: () => onPaymentMethodChanged('yappy'),
              ),
              if (deliveryType == 'pickup') ...[
                const SizedBox(height: 12),
                _RadioCard(
                  title: 'Pago en tienda',
                  subtitle: 'Pagar al recoger tu pedido',
                  icon: Icons.store_outlined,
                  selected: paymentMethod == 'in_store',
                  onTap: () => onPaymentMethodChanged('in_store'),
                ),
              ],
            ],
          ),
        ),
        _BottomButton(label: 'Continuar', onPressed: onNext),
      ],
    );
  }
}

// ── Step 3: Summary ───────────────────────────────────────────────

class _SummaryStep extends ConsumerWidget {
  final Cart cart;
  final String deliveryType;
  final int? selectedBranchId;
  final String? selectedAddressId;
  final String paymentMethod;
  final String? notes;
  final bool isSubmitting;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onConfirm;
  final ValueChanged<String>? onAddressChanged;

  const _SummaryStep({
    super.key,
    required this.cart,
    required this.deliveryType,
    required this.selectedBranchId,
    required this.selectedAddressId,
    required this.paymentMethod,
    required this.notes,
    required this.isSubmitting,
    required this.onNotesChanged,
    required this.onConfirm,
    this.onAddressChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = cart.subtotal; // Sin fee — ASAP cobra aparte
    final branches = ref.watch(branchListProvider).valueOrNull ?? [];
    final branch = branches.where((b) => b.id == selectedBranchId).firstOrNull;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(Responsive.padding(context)),
            children: [
              // Items summary
              Text(
                'Productos (${cart.items.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...cart.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.quantity}x ${item.productName ?? "Producto"}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '\$${item.lineTotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),

              // Delivery info with map
              _SummaryRow(
                label: 'Entrega',
                value: deliveryType == 'pickup'
                    ? 'Recoger en tienda'
                    : 'Delivery via ASAP',
              ),
              if (branch != null)
                _SummaryRow(label: 'Sucursal', value: branch.name),
              if (deliveryType == 'delivery' && selectedAddressId != null)
                _buildAddressRow(ref, context),
              if (branch != null)
                _buildDeliveryMap(ref, context, branch),
              _SummaryRow(label: 'Pago', value: _paymentLabel(paymentMethod)),
              const Divider(height: 24),

              // Totals
              _SummaryRow(
                label: 'Subtotal',
                value: '\$${cart.subtotal.toStringAsFixed(2)}',
              ),
              _SummaryRow(
                label: 'Delivery',
                value: deliveryType == 'delivery'
                    ? 'Coordinado por ASAP'
                    : 'Gratis',
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              if (deliveryType == 'delivery') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El costo de envío lo gestiona y cobra ASAP directamente.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Notes
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'Instrucciones de entrega, alergias, etc.',
                ),
                maxLines: 2,
                maxLength: 500,
                onChanged: onNotesChanged,
              ),
            ],
          ),
        ),
        _BottomButton(
          label: isSubmitting
              ? 'Procesando...'
              : _confirmLabel(paymentMethod, total),
          onPressed: isSubmitting ? null : onConfirm,
        ),
      ],
    );
  }

  String _confirmLabel(String method, double total) {
    final amount = '\$${total.toStringAsFixed(2)}';
    return switch (method) {
      'tilopay' => 'Pagar  •  $amount',
      'in_store' => 'Confirmar Pedido  •  $amount',
      _ => 'Confirmar Pedido  •  $amount',
    };
  }

  Widget _buildAddressRow(WidgetRef ref, BuildContext context) {
    final addresses = ref.watch(_addressesProvider).valueOrNull ?? [];
    final addr = addresses.where((a) => a['id'] == selectedAddressId).firstOrNull;
    if (addr == null) return const SizedBox.shrink();
    final label = addr['label'] as String? ?? '';
    final line = addr['address_line'] as String? ?? '';
    final display = label.isNotEmpty ? '$label — $line' : line;

    // Calculate distance from branch to delivery address
    final branches = ref.watch(branchListProvider).valueOrNull ?? [];
    final branch = branches.where((b) => b.id == selectedBranchId).firstOrNull;
    final addrLat = (addr['latitude'] as num?)?.toDouble();
    final addrLng = (addr['longitude'] as num?)?.toDouble();
    String? distanceText;
    if (branch != null && branch.latitude != null && branch.longitude != null &&
        addrLat != null && addrLng != null) {
      final km = _haversineKm(addrLat, addrLng, branch.latitude!, branch.longitude!);
      distanceText = km < 1
          ? '${(km * 1000).round()} m de la sucursal'
          : '${km.toStringAsFixed(1)} km de la sucursal';
    }

    return Column(
      children: [
        InkWell(
          onTap: onAddressChanged != null ? () async {
            final addresses = ref.read(_addressesProvider).valueOrNull ?? [];
            if (addresses.isEmpty) return;
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => DraggableScrollableSheet(
                initialChildSize: 0.5,
                minChildSize: 0.3,
                maxChildSize: 0.8,
                expand: false,
                builder: (ctx, scrollController) => ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Cambiar dirección',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...addresses.map((a) {
                      final aId = a['id'] as String;
                      final aLabel = a['label'] as String? ?? 'Dirección';
                      final aLine = a['address_line'] as String? ?? '';
                      return ListTile(
                        leading: Icon(
                          selectedAddressId == aId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selectedAddressId == aId
                              ? AppColors.primary
                              : null,
                        ),
                        title: Text(aLabel),
                        subtitle: Text(aLine, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          onAddressChanged!(aId);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          } : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryRow(label: 'Dirección', value: display),
                ),
                if (onAddressChanged != null)
                  Icon(Icons.edit_location_alt, size: 20, color: AppColors.primary),
              ],
            ),
          ),
        ),
        if (distanceText != null)
          _SummaryRow(label: 'Distancia', value: distanceText),
      ],
    );
  }

  Widget _buildDeliveryMap(WidgetRef ref, BuildContext context, Branch branch) {
    if (branch.latitude == null || branch.longitude == null) {
      return const SizedBox.shrink();
    }

    final branchLatLng = LatLng(branch.latitude!, branch.longitude!);

    // Get address coordinates if delivery
    LatLng? addrLatLng;
    if (deliveryType == 'delivery' && selectedAddressId != null) {
      final addresses = ref.watch(_addressesProvider).valueOrNull ?? [];
      final addr = addresses.where((a) => a['id'] == selectedAddressId).firstOrNull;
      if (addr != null) {
        final lat = (addr['latitude'] as num?)?.toDouble();
        final lng = (addr['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          addrLatLng = LatLng(lat, lng);
        }
      }
    }

    // Calculate map bounds
    final center = addrLatLng != null
        ? LatLng(
            (branchLatLng.latitude + addrLatLng.latitude) / 2,
            (branchLatLng.longitude + addrLatLng.longitude) / 2,
          )
        : branchLatLng;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 180,
          child: _DeliveryMapWidget(
            branchLatLng: branchLatLng,
            addrLatLng: addrLatLng,
            center: center,
            branchName: branch.name,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      ),
    );
  }

  String _paymentLabel(String method) {
    return switch (method) {
      'tilopay' => 'Tarjeta de crédito / débito',
      'yappy' => 'Yappy',
      'in_store' => 'Pago en tienda',
      _ => method,
    };
  }
}

// ── Delivery Map Widget ────────────────────────────────────────────

class _DeliveryMapWidget extends StatefulWidget {
  final LatLng branchLatLng;
  final LatLng? addrLatLng;
  final LatLng center;
  final String branchName;
  final bool isDark;

  const _DeliveryMapWidget({
    required this.branchLatLng,
    required this.addrLatLng,
    required this.center,
    required this.branchName,
    required this.isDark,
  });

  @override
  State<_DeliveryMapWidget> createState() => _DeliveryMapWidgetState();
}

class _DeliveryMapWidgetState extends State<_DeliveryMapWidget> {
  final MapController _mapController = MapController();

  /// 3D-perspective arc: cubic bezier with two control points offset
  /// upward (perpendicular) creating a parabolic "flight path" look.
  /// The arc height scales with the distance between points.
  List<LatLng> _buildArc3D(LatLng from, LatLng to, {int segments = 40}) {
    final dLat = to.latitude - from.latitude;
    final dLng = to.longitude - from.longitude;
    final dist = sqrt(dLat * dLat + dLng * dLng);
    if (dist == 0) return [from, to];

    // Arc height proportional to distance — closer = smaller arc
    final bulge = dist * 0.35;

    // Perpendicular unit vector (rotated 90°)
    final perpLat = -dLng / dist;
    final perpLng = dLat / dist;

    // Two control points at 1/3 and 2/3 along the line,
    // with asymmetric heights for a 3D perspective feel
    final cp1Lat = from.latitude + dLat * 0.3 + perpLat * bulge * 0.9;
    final cp1Lng = from.longitude + dLng * 0.3 + perpLng * bulge * 0.9;
    final cp2Lat = from.latitude + dLat * 0.7 + perpLat * bulge * 0.9;
    final cp2Lng = from.longitude + dLng * 0.7 + perpLng * bulge * 0.9;

    // Cubic bezier
    final points = <LatLng>[];
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final u = 1 - t;
      final lat = u * u * u * from.latitude +
          3 * u * u * t * cp1Lat +
          3 * u * t * t * cp2Lat +
          t * t * t * to.latitude;
      final lng = u * u * u * from.longitude +
          3 * u * u * t * cp1Lng +
          3 * u * t * t * cp2Lng +
          t * t * t * to.longitude;
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  void _fitMapToPoints() {
    if (!mounted) return;
    if (widget.addrLatLng != null) {
      // Fit both markers with padding
      final bounds = LatLngBounds(widget.branchLatLng, widget.addrLatLng!);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
      );
    } else {
      _mapController.move(widget.branchLatLng, 15.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: 14.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
        onMapReady: () {
          Future.delayed(const Duration(milliseconds: 80), () {
            _fitMapToPoints();
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: widget.isDark
              ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
              : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
          userAgentPackageName: 'com.blackdogpanama.blackdog_app',
        ),
        // 3D curved arc between branch and address
        if (widget.addrLatLng != null) ...[
          // Shadow line (offset down, semi-transparent)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _buildArc3D(widget.branchLatLng, widget.addrLatLng!)
                    .map((p) => LatLng(p.latitude - 0.0002, p.longitude + 0.0002))
                    .toList(),
                strokeWidth: 5,
                color: Colors.black.withValues(alpha: 0.15),
              ),
            ],
          ),
          // Main arc line
          PolylineLayer(
            polylines: [
              Polyline(
                points: _buildArc3D(widget.branchLatLng, widget.addrLatLng!),
                strokeWidth: 3.5,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
        // Markers
        MarkerLayer(
          markers: [
            // Branch marker
            Marker(
              point: widget.branchLatLng,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.asset('assets/icons/Logo_Head.png'),
                ),
              ),
            ),
            // Delivery address marker
            if (widget.addrLatLng != null)
              Marker(
                point: widget.addrLatLng!,
                width: 36,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────

class _RadioCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _RadioCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 8 : 12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: compact ? 20 : 24,
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Flexible(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _BottomButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onPressed, child: Text(label)),
        ),
      ),
    );
  }
}

// ── Haversine distance helper ──────────────────────────────────────
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * (pi / 180);
  final dLon = (lon2 - lon1) * (pi / 180);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
      sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
