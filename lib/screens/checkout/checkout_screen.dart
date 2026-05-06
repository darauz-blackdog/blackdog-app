import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/cart.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_branch_provider.dart';
import '../../providers/service_providers.dart';
import '../../utils/error_utils.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/step_indicator.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _step = 0; // 0=branch, 1=payment, 2=summary
  int? _selectedBranchId;
  String _paymentMethod = 'tilopay';
  String? _notes;
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFromProviders());
  }

  void _initFromProviders() {
    if (_initialized) return;
    _initialized = true;

    final ranked = ref.read(rankedBranchesProvider).valueOrNull;
    if (ranked != null && ranked.isNotEmpty) {
      final best = ranked.where((r) => r.branch.isPickupEnabled && r.hasFullStock).firstOrNull;
      if (best != null) _selectedBranchId = best.branch.id;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            labels: const ['Sucursal', 'Pago', 'Resumen'],
          ),
          Expanded(
            child: ResponsiveCenter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildCurrentStep(cart),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 0: return 'Sucursal';
      case 1: return 'Método de pago';
      case 2: return 'Resumen del pedido';
      default: return 'Checkout';
    }
  }

  Widget _buildCurrentStep(Cart cart) {
    switch (_step) {
      case 0:
        return _BranchStep(
          key: const ValueKey('branch'),
          selectedBranchId: _selectedBranchId,
          onBranchSelected: (id) => setState(() => _selectedBranchId = id),
          onNext: _selectedBranchId != null ? () => setState(() => _step = 1) : null,
        );
      case 1:
        return _PaymentStep(
          key: const ValueKey('payment'),
          paymentMethod: _paymentMethod,
          onPaymentMethodChanged: (v) => setState(() => _paymentMethod = v),
          onNext: () => setState(() => _step = 2),
        );
      case 2:
        return _SummaryStep(
          key: const ValueKey('summary'),
          cart: cart,
          selectedBranchId: _selectedBranchId,
          paymentMethod: _paymentMethod,
          notes: _notes,
          isSubmitting: _isSubmitting,
          onNotesChanged: (v) => _notes = v,
          onConfirm: _submitOrder,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.createOrder(
        deliveryType: 'pickup',
        branchId: _selectedBranchId!,
        paymentMethod: _paymentMethod,
        notes: _notes,
      );

      ref.read(cartProvider.notifier).refresh();

      if (!mounted) return;

      final orderId = result['order']?['id'] as String? ?? '';
      final orderName = result['order']?['payment_reference'] as String? ??
          result['odoo_order_name'] as String?;
      final total = (result['order']?['total'] as num?)?.toDouble();

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
        if (!result.containsKey('payment_method')) {
          result['payment_method'] = _paymentMethod;
        }
        context.go('/order-confirmation/$orderId', extra: result);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

// ── Step 1: Branch (pickup only) ──────────────────────────────────

class _BranchStep extends ConsumerWidget {
  final int? selectedBranchId;
  final ValueChanged<int> onBranchSelected;
  final VoidCallback? onNext;

  const _BranchStep({
    super.key,
    required this.selectedBranchId,
    required this.onBranchSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankedAsync = ref.watch(rankedBranchesProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(Responsive.padding(context)),
            children: [
              Text(
                'Selecciona la sucursal donde recoger tu pedido',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              rankedAsync.when(
                data: (list) {
                  final pickupBranches = list
                      .where((r) => r.branch.isPickupEnabled)
                      .toList();

                  if (pickupBranches.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay sucursales disponibles para pickup.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return Column(
                    children: pickupBranches.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BranchCard(
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
          ),
        ),
        _BottomButton(label: 'Continuar', onPressed: onNext),
      ],
    );
  }
}

class _BranchCard extends StatelessWidget {
  final RankedBranch ranked;
  final bool selected;
  final VoidCallback? onTap;

  const _BranchCard({
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
            color: selected ? AppColors.primary : Theme.of(context).colorScheme.outline,
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

// ── Step 2: Payment Method ─────────────────────────────────────────

class _PaymentStep extends StatelessWidget {
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onNext;

  const _PaymentStep({
    super.key,
    required this.paymentMethod,
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
              const SizedBox(height: 12),
              _RadioCard(
                title: 'Pago en tienda',
                subtitle: 'Pagar al recoger tu pedido',
                icon: Icons.store_outlined,
                selected: paymentMethod == 'in_store',
                onTap: () => onPaymentMethodChanged('in_store'),
              ),
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
  final int? selectedBranchId;
  final String paymentMethod;
  final String? notes;
  final bool isSubmitting;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onConfirm;

  const _SummaryStep({
    super.key,
    required this.cart,
    required this.selectedBranchId,
    required this.paymentMethod,
    required this.notes,
    required this.isSubmitting,
    required this.onNotesChanged,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = cart.subtotal;
    final branches = ref.watch(branchListProvider).valueOrNull ?? [];
    final branch = branches.where((b) => b.id == selectedBranchId).firstOrNull;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(Responsive.padding(context)),
            children: [
              Text(
                'Productos (${cart.items.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
              _SummaryRow(label: 'Entrega', value: 'Recoger en tienda'),
              if (branch != null) _SummaryRow(label: 'Sucursal', value: branch.name),
              _SummaryRow(label: 'Pago', value: _paymentLabel(paymentMethod)),
              const Divider(height: 24),
              _SummaryRow(
                label: 'Subtotal',
                value: '\$${cart.subtotal.toStringAsFixed(2)}',
              ),
              _SummaryRow(label: 'Delivery', value: 'Gratis'),
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
              const SizedBox(height: 24),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'Instrucciones especiales, etc.',
                ),
                maxLines: 2,
                maxLength: 500,
                onChanged: onNotesChanged,
              ),
            ],
          ),
        ),
        _BottomButton(
          label: isSubmitting ? 'Procesando...' : _confirmLabel(paymentMethod, total),
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

  String _paymentLabel(String method) {
    return switch (method) {
      'tilopay' => 'Tarjeta de crédito / débito',
      'yappy' => 'Yappy',
      'in_store' => 'Pago en tienda',
      _ => method,
    };
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────

class _RadioCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RadioCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? AppColors.primary : Theme.of(context).hintColor,
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
              const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
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
