import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/branch.dart';
import '../../models/cart.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/service_providers.dart';
import '../../utils/error_utils.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

/// Providers local to checkout
final _branchesProvider = FutureProvider<List<Branch>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getBranches();
  return data.map((b) => Branch.fromJson(b as Map<String, dynamic>)).toList();
});

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

  void _initFromProviders() {
    if (_initialized) return;
    _initialized = true;

    final nearest = ref.read(nearestBranchProvider);
    final address = ref.read(selectedAddressProvider).valueOrNull;

    if (nearest != null) {
      _selectedBranchId = nearest.branch.id;
      if (nearest.isDeliveryAvailable && address != null) {
        _deliveryType = 'delivery';
        _selectedAddressId = address.id;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _initFromProviders();
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
      body: ResponsiveCenter(child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildCurrentStep(cart),
      )),
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
            if (v == 'pickup') _selectedAddressId = null;
          }),
          onBranchSelected: (id) => setState(() => _selectedBranchId = id),
          onAddressSelected: (id) => setState(() => _selectedAddressId = id),
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

      if (mounted) {
        final orderId = result['order']?['id'] as String? ?? '';
        context.go('/order-confirmation/$orderId', extra: result);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        final message = friendlyError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
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
    final branches = ref.watch(_branchesProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(Responsive.padding(context)),
            children: [
              // Delivery type radio cards
              _RadioCard(
                title: 'Recoger en tienda',
                subtitle: 'Sin costo de delivery',
                icon: Icons.store_outlined,
                selected: deliveryType == 'pickup',
                onTap: () => onDeliveryTypeChanged('pickup'),
              ),
              const SizedBox(height: 12),
              Consumer(builder: (context, ref, _) {
                final nearest = ref.watch(nearestBranchProvider);
                final canDeliver = nearest?.isDeliveryAvailable ?? true;
                return _RadioCard(
                  title: 'Delivery a domicilio',
                  subtitle: canDeliver
                      ? 'Costo: \$3.50'
                      : 'Solo recogida — dirección a más de 2km',
                  icon: Icons.delivery_dining_outlined,
                  selected: deliveryType == 'delivery',
                  onTap: canDeliver
                      ? () => onDeliveryTypeChanged('delivery')
                      : () {},
                  compact: !canDeliver,
                );
              }),
              const SizedBox(height: 24),

              // Branch selector (always shown — used as source warehouse)
              Text(
                'Sucursal',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              branches.when(
                data: (list) => Column(
                  children: list
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _RadioCard(
                            title: b.name,
                            subtitle: b.address ?? '',
                            icon: Icons.location_on_outlined,
                            selected: selectedBranchId == b.id,
                            onTap: () => onBranchSelected(b.id),
                            compact: true,
                          ),
                        ),
                      )
                      .toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (context, error) =>
                    const Text('Error cargando sucursales'),
              ),

              // Address selector (only for delivery)
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
                        final result = await context.push<bool>('/profile/addresses/add');
                        if (result == true) {
                          ref.invalidate(_addressesProvider);
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildAddressList(context, ref),
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
      error: (context, error) => const Text('Error cargando direcciones'),
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
                icon: Icons.credit_card,
                selected: paymentMethod == 'tilopay',
                onTap: () => onPaymentMethodChanged('tilopay'),
              ),
              const SizedBox(height: 12),
              _RadioCard(
                title: 'Yappy',
                subtitle: 'Pago móvil',
                icon: Icons.phone_android,
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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryFee = deliveryType == 'delivery' ? 3.50 : 0.0;
    final total = cart.subtotal + deliveryFee;
    final branches = ref.watch(_branchesProvider).valueOrNull ?? [];
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

              // Delivery info
              _SummaryRow(
                label: 'Entrega',
                value: deliveryType == 'pickup'
                    ? 'Recoger en tienda'
                    : 'Delivery a domicilio',
              ),
              if (branch != null)
                _SummaryRow(label: 'Sucursal', value: branch.name),
              if (deliveryType == 'delivery' && selectedAddressId != null)
                _buildAddressRow(ref),
              _SummaryRow(label: 'Pago', value: _paymentLabel(paymentMethod)),
              const Divider(height: 24),

              // Totals
              _SummaryRow(
                label: 'Subtotal',
                value: '\$${cart.subtotal.toStringAsFixed(2)}',
              ),
              _SummaryRow(
                label: 'Delivery',
                value: deliveryFee > 0
                    ? '\$${deliveryFee.toStringAsFixed(2)}'
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
              const SizedBox(height: 24),

              // Notes
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'Instrucciones de entrega, alergias, etc.',
                ),
                maxLines: 2,
                onChanged: onNotesChanged,
              ),
            ],
          ),
        ),
        _BottomButton(
          label: isSubmitting
              ? 'Procesando...'
              : 'Confirmar Pedido  •  \$${total.toStringAsFixed(2)}',
          onPressed: isSubmitting ? null : onConfirm,
        ),
      ],
    );
  }

  Widget _buildAddressRow(WidgetRef ref) {
    final addresses = ref.watch(_addressesProvider).valueOrNull ?? [];
    final addr = addresses.where((a) => a['id'] == selectedAddressId).firstOrNull;
    if (addr == null) return const SizedBox.shrink();
    final label = addr['label'] as String? ?? '';
    final line = addr['address_line'] as String? ?? '';
    final display = label.isNotEmpty ? '$label — $line' : line;
    return _SummaryRow(label: 'Dirección', value: display);
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
