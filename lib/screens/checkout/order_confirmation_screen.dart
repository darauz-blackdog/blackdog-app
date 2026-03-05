import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/fade_in_up.dart';

class OrderConfirmationScreen extends ConsumerStatefulWidget {
  final String orderId;
  final Map<String, dynamic>? orderData;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    this.orderData,
  });

  @override
  ConsumerState<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState
    extends ConsumerState<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconCtrl;
  late Animation<double> _iconScale;
  late Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.easeOutCubic));
    _iconRotation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconCtrl.forward();
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order =
        widget.orderData?['order'] as Map<String, dynamic>? ?? {};
    final paymentUrl = widget.orderData?['payment_url'] as String?;
    final orderNumber = widget.orderData?['odoo_order_name'] as String? ??
        order['payment_reference'] as String? ??
        widget.orderId.substring(0, 8).toUpperCase();
    final total = (order['total'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.padding(context)),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Animated success icon
              AnimatedBuilder(
                animation: _iconCtrl,
                builder: (context, child) => Transform.scale(
                  scale: _iconScale.value,
                  child: Transform.rotate(
                    angle: _iconRotation.value,
                    child: child,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 80,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeInUp(
                delay: 300,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  '¡Pedido Creado!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              FadeInUp(
                delay: 400,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  'Pedido #$orderNumber',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              FadeInUp(
                delay: 500,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  'Total: \$${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
              ),
              const SizedBox(height: 32),

              // Payment section
              if (paymentUrl != null)
                FadeInUp(
                  delay: 600,
                  offset: 20,
                  duration: const Duration(milliseconds: 500),
                  child: _buildTilopaySection(context, paymentUrl),
                ),

              const SizedBox(height: 40),

              // Actions
              FadeInUp(
                delay: 700,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    if (paymentUrl != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go(
                            '/payment/${widget.orderId}',
                            extra: {
                              'payment_url': paymentUrl,
                              'payment_method': 'tilopay',
                            },
                          ),
                          child: const Text('Ver estado del pago'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: paymentUrl == null
                          ? ElevatedButton(
                              onPressed: () => context.go('/home'),
                              child: const Text('Seguir comprando'),
                            )
                          : OutlinedButton(
                              onPressed: () => context.go('/home'),
                              child: const Text('Seguir comprando'),
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go('/orders'),
                        child: const Text('Mis pedidos'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTilopaySection(BuildContext context, String paymentUrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.credit_card, size: 40, color: AppColors.info),
          const SizedBox(height: 12),
          Text('Pagar con tarjeta',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Serás redirigido a Tilopay para completar tu pago de forma segura.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openPaymentLink(paymentUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ir a pagar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaymentLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
