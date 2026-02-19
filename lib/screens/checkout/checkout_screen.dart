import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/branch.dart';
import '../../models/cart.dart';
import '../../providers/cart_provider.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import 'add_address_sheet.dart';

/// Providers local to checkout
final _branchesProvider = FutureProvider<List<Branch>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getBranches();
  return data.map((b) => Branch.fromJson(b as Map<String, dynamic>)).toList();
});

final _addressesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
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

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).valueOrNull;

    if (cart == null || cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('Tu carrito está vacío')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _step > 0 ? () => setState(() => _step--) : () => context.pop(),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildCurrentStep(cart),
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 0: return 'Método de entrega';
      case 1: return 'Método de pago';
      case 2: return 'Resumen del pedido';
      default: return 'Checkout';
    }
  }

  Widget _buildCurrentStep(Cart cart) {
    switch (_step) {
      case 0: return _DeliveryStep(
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
      case 1: return _PaymentStep(
        key: const ValueKey('payment'),
        paymentMethod: _paymentMethod,
        deliveryType: _deliveryType,
        onPaymentMethodChanged: (v) => setState(() => _paymentMethod = v),
        onNext: () => setState(() => _step = 2),
      );
      case 2: return _SummaryStep(
        key: const ValueKey('summary'),
        cart: cart,
        deliveryType: _deliveryType,
        selectedBranchId: _selectedBranchId,
        paymentMethod: _paymentMethod,
        notes: _notes,
        isSubmitting: _isSubmitting,
        onNotesChanged: (v) => _notes = v,
        onConfirm: _submitOrder,
      );
      default: return const SizedBox.shrink();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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
            padding: const EdgeInsets.all(20),
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
              _RadioCard(
                title: 'Delivery a domicilio',
                subtitle: 'Costo: \$3.50',
                icon: Icons.delivery_dining_outlined,
                selected: deliveryType == 'delivery',
                onTap: () => onDeliveryTypeChanged('delivery'),
              ),
              const SizedBox(height: 24),

              // Branch selector (always shown — used as source warehouse)
              Text('Sucursal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              branches.when(
                data: (list) => Column(
                  children: list.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RadioCard(
                      title: b.name,
                      subtitle: b.address ?? '',
                      icon: Icons.location_on_outlined,
                      selected: selectedBranchId == b.id,
                      onTap: () => onBranchSelected(b.id),
                      compact: true,
                    ),
                  )).toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error cargando sucursales'),
              ),

              // Address selector (only for delivery)
              if (deliveryType == 'delivery') ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dirección de entrega',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const AddAddressSheet(),
                        );
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
        _BottomButton(
          label: 'Continuar',
          onPressed: onNext,
        ),
      ],
    );
  }

  Widget _buildAddressList(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(_addressesProvider);

    return addresses.when(
      data: (list) {
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
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
      error: (_, __) => const Text('Error cargando direcciones'),
    );
  }
}

// ── Step 2: Payment ───────────────────────────────────────────────

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
            padding: const EdgeInsets.all(20),
            children: [
              _RadioCard(
                title: 'Tarjeta de crédito / débito',
                subtitle: 'Pago seguro vía Tilopay',
                icon: Icons.credit_card_outlined,
                selected: paymentMethod == 'tilopay',
                onTap: () => onPaymentMethodChanged('tilopay'),
              ),
              const SizedBox(height: 12),
              _RadioCard(
                title: 'Yappy',
                subtitle: 'Transferencia vía Yappy',
                icon: Icons.phone_android_outlined,
                selected: paymentMethod == 'yappy',
                onTap: () => onPaymentMethodChanged('yappy'),
              ),
              if (deliveryType == 'pickup') ...[
                const SizedBox(height: 12),
                _RadioCard(
                  title: 'Pago en tienda',
                  subtitle: 'Paga al recoger tu pedido',
                  icon: Icons.storefront_outlined,
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
            padding: const EdgeInsets.all(20),
            children: [
              // Items summary
              Text('Productos (${cart.items.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...cart.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.productName ?? "Producto"}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text('\$${item.lineTotal.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )),
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
              _SummaryRow(
                label: 'Pago',
                value: _paymentLabel(paymentMethod),
              ),
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
                  Text('Total',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700)),
                  Text('\$${total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          )),
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
          label: isSubmitting ? 'Procesando...' : 'Confirmar Pedido  •  \$${total.toStringAsFixed(2)}',
          onPressed: isSubmitting ? null : onConfirm,
        ),
      ],
    );
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'tilopay': return 'Tarjeta (Tilopay)';
      case 'yappy': return 'Yappy';
      case 'in_store': return 'Pago en tienda';
      default: return method;
    }
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
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
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
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: compact ? 20 : 24,
                  color: selected ? AppColors.primary : AppColors.textLight),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          )),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
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
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500)),
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
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPressed,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
