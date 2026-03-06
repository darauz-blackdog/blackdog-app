import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/payment_state.dart';
import '../../providers/payment_provider.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/payment_countdown.dart';
import '../../widgets/payment_result_view.dart';

class YappyPaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String? orderName;
  final double? amount;

  const YappyPaymentScreen({
    super.key,
    required this.orderId,
    this.orderName,
    this.amount,
  });

  @override
  ConsumerState<YappyPaymentScreen> createState() =>
      _YappyPaymentScreenState();
}

class _YappyPaymentScreenState extends ConsumerState<YappyPaymentScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _submitting = false;
  String? _phoneError;

  late final PaymentSessionParams _params;

  @override
  void initState() {
    super.initState();
    _params = PaymentSessionParams(
      orderId: widget.orderId,
      paymentMethod: 'yappy',
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  String _cleanPhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  bool _validatePhone() {
    final clean = _cleanPhone(_phoneController.text);
    if (clean.length < 7 || clean.length > 8) {
      setState(() => _phoneError = 'Ingresa un número válido (7-8 dígitos)');
      return false;
    }
    if (!clean.startsWith('6')) {
      setState(() => _phoneError = 'El número debe empezar con 6');
      return false;
    }
    setState(() => _phoneError = null);
    return true;
  }

  Future<void> _submitPayment() async {
    if (!_validatePhone() || _submitting) return;

    setState(() => _submitting = true);
    final phone = _cleanPhone(_phoneController.text);

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.createYappyPayment(widget.orderId, phone);

      if (!mounted) return;

      // Store Yappy instructions from response
      final notifier = ref.read(paymentProvider(_params).notifier);
      notifier.setYappyInstructions(result);
      notifier.startPayment();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear pago Yappy: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _retry() {
    setState(() => _submitting = false);
    ref.read(paymentProvider(_params).notifier).retry();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(paymentProvider(_params));

    return Scaffold(
      appBar: AppBar(title: const Text('Pagar con Yappy')),
      body: _buildBody(session),
    );
  }

  Widget _buildBody(PaymentSession session) {
    // Success
    if (session.state == PaymentState.paid) {
      return ResponsiveCenter(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.padding(context)),
          child: PaymentResultView(
            isSuccess: true,
            title: '¡Pago completado!',
            subtitle: 'Tu pago con Yappy se ha confirmado.',
            orderName: widget.orderName,
            paymentMethod: 'yappy',
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/orders/${widget.orderId}'),
                  child: const Text('Ver pedido'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Seguir comprando'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No retries left
    if (session.state.isRetryable && !session.canRetry) {
      return ResponsiveCenter(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.padding(context)),
          child: PaymentResultView(
            isSuccess: false,
            title: session.state.label,
            subtitle: 'Se agotaron los intentos disponibles.',
            orderName: widget.orderName,
            paymentMethod: 'yappy',
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/orders/${widget.orderId}'),
                  child: const Text('Ver pedido'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Seguir comprando'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Waiting for payment confirmation (after phone submitted)
    if (session.state.isWaiting && _submitting) {
      return _buildWaitingView(session);
    }

    // Retry state
    if (session.canRetry) {
      return _buildRetryView(session);
    }

    // Initial: phone input
    return _buildPhoneInput(session);
  }

  Widget _buildPhoneInput(PaymentSession session) {
    return ResponsiveCenter(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.padding(context)),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Yappy logo area
            FadeInUp(
              delay: 0,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C2DC7).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  size: 64,
                  color: Color(0xFF6C2DC7),
                ),
              ),
            ),
            const SizedBox(height: 24),

            FadeInUp(
              delay: 100,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Text(
                'Pagar con Yappy',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),

            FadeInUp(
              delay: 150,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Text(
                'Ingresa tu número de teléfono y confirma el pago en tu app Yappy.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Amount
            if (widget.amount != null) ...[
              const SizedBox(height: 20),
              FadeInUp(
                delay: 175,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  '\$${widget.amount!.toStringAsFixed(2)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Phone input
            FadeInUp(
              delay: 200,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    maxLength: 8,
                    style: GoogleFonts.inter(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Número de teléfono',
                      hintText: '6XXX-XXXX',
                      prefixIcon: const Icon(Icons.phone),
                      prefixText: '+507 ',
                      counterText: '',
                      errorText: _phoneError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) {
                      if (_phoneError != null) {
                        setState(() => _phoneError = null);
                      }
                    },
                    onSubmitted: (_) => _submitPayment(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submitPayment,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _submitting ? 'Enviando...' : 'Pagar con Yappy',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C2DC7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Security badge
            FadeInUp(
              delay: 300,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 16, color: AppColors.textLight),
                  const SizedBox(width: 6),
                  Text(
                    'Procesado por Yappy',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingView(PaymentSession session) {
    return ResponsiveCenter(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.padding(context)),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Countdown
            FadeInUp(
              delay: 0,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: PaymentCountdown(session: session, size: 160),
            ),
            const SizedBox(height: 32),

            // Message
            FadeInUp(
              delay: 100,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Text(
                'Confirma el pago en tu app Yappy',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            FadeInUp(
              delay: 150,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Text(
                'Abre tu app Yappy y aprueba la solicitud de pago que acabas de recibir.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Amount + order
            if (widget.amount != null || widget.orderName != null) ...[
              const SizedBox(height: 24),
              FadeInUp(
                delay: 175,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (widget.amount != null)
                        Text(
                          '\$${widget.amount!.toStringAsFixed(2)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      if (widget.orderName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.orderName!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Polling indicator
            FadeInUp(
              delay: 200,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Esperando confirmación...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Yappy badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 16, color: AppColors.textLight),
                const SizedBox(width: 6),
                Text(
                  'Procesado por Yappy',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryView(PaymentSession session) {
    return ResponsiveCenter(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.padding(context)),
        child: Column(
          children: [
            const SizedBox(height: 40),

            FadeInUp(
              delay: 0,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  session.state == PaymentState.expired
                      ? Icons.timer_off_rounded
                      : Icons.error_outline_rounded,
                  size: 64,
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 24),

            FadeInUp(
              delay: 100,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Text(
                session.state.label,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),

            FadeInUp(
              delay: 150,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Text(
                session.errorMessage ?? session.state.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 32),

            FadeInUp(
              delay: 200,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'Intentar de nuevo (${session.retriesRemaining} restantes)',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C2DC7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/orders/${widget.orderId}'),
                    child: const Text('Ver pedido'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
