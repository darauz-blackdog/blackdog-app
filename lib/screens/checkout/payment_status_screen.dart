import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/payment_state.dart';
import '../../providers/payment_provider.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/fade_in_up.dart';

class PaymentStatusScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String? paymentUrl;
  final String? paymentMethod;

  const PaymentStatusScreen({
    super.key,
    required this.orderId,
    this.paymentUrl,
    this.paymentMethod,
  });

  @override
  ConsumerState<PaymentStatusScreen> createState() =>
      _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen> {
  WebViewController? _webViewController;
  bool _webViewLoading = true;
  bool _showWebView = false;

  late final PaymentSessionParams _params;

  @override
  void initState() {
    super.initState();
    _params = PaymentSessionParams(
      orderId: widget.orderId,
      paymentMethod: widget.paymentMethod ?? 'tilopay',
      paymentUrl: widget.paymentUrl,
    );

    // Load Yappy instructions if needed
    if (widget.paymentMethod == 'yappy') {
      _loadYappyInstructions();
    }

    // Start payment flow after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentProvider(_params).notifier).startPayment();
    });
  }

  Future<void> _loadYappyInstructions() async {
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.getYappyInstructions(widget.orderId);
      if (mounted) {
        ref.read(paymentProvider(_params).notifier).setYappyInstructions(result);
      }
    } catch (_) {}
  }

  void _openPayment() {
    if (widget.paymentUrl == null) return;

    if (kIsWeb) {
      final uri = Uri.parse(widget.paymentUrl!);
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    final notifier = ref.read(paymentProvider(_params).notifier);

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
            final url = request.url.toLowerCase();
            if (url.contains('payment/success') ||
                url.contains('payment/callback') ||
                url.contains('status=approved')) {
              notifier.markProcessing();
              setState(() => _showWebView = false);
              return NavigationDecision.prevent;
            }
            if (url.contains('payment/cancel') ||
                url.contains('payment/failed') ||
                url.contains('status=declined')) {
              notifier.markFailed('El pago fue rechazado por el gateway.');
              setState(() => _showWebView = false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl!));

    setState(() {
      _webViewController = controller;
      _showWebView = true;
      _webViewLoading = true;
    });
  }

  void _retryPayment() {
    ref.read(paymentProvider(_params).notifier).retry();
    if (widget.paymentMethod == 'tilopay' && widget.paymentUrl != null) {
      _openPayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(paymentProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: Text(_showWebView ? 'Pago seguro' : 'Estado del pago'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_showWebView) {
              setState(() => _showWebView = false);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: _showWebView ? _buildWebView() : _buildStatusView(session),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        if (_webViewController != null)
          WebViewWidget(controller: _webViewController!),
        if (_webViewLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildStatusView(PaymentSession session) {
    return ResponsiveCenter(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.padding(context)),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Status icon
            FadeInUp(
              delay: 0,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: _buildStatusIcon(session.state),
            ),
            const SizedBox(height: 24),

            // Status title
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

            // Status description
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

            // Countdown timer
            if (session.isCountdownActive) ...[
              const SizedBox(height: 20),
              FadeInUp(
                delay: 175,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: _buildCountdown(session),
              ),
            ],

            const SizedBox(height: 32),

            // Yappy instructions
            if (widget.paymentMethod == 'yappy' &&
                session.yappyInstructions != null)
              FadeInUp(
                delay: 200,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: _buildYappySection(session.yappyInstructions!),
              ),

            // Pay button (Tilopay)
            if (widget.paymentUrl != null &&
                (session.state == PaymentState.draft ||
                 session.state == PaymentState.pending))
              FadeInUp(
                delay: 200,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openPayment,
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Pagar ahora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),

            // Retry button
            if (session.canRetry) ...[
              const SizedBox(height: 24),
              FadeInUp(
                delay: 250,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _retryPayment,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          'Intentar de nuevo (${session.retriesRemaining} restantes)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/orders/${widget.orderId}'),
                      child: const Text('Ver pedido'),
                    ),
                  ],
                ),
              ),
            ],

            // Terminal state actions (paid or no retries left)
            if (session.state == PaymentState.paid ||
                (session.state.isRetryable && !session.canRetry)) ...[
              const SizedBox(height: 24),
              FadeInUp(
                delay: 300,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.go('/orders/${widget.orderId}'),
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
            ],

            // Polling indicator
            if (session.state.isWaiting) ...[
              const SizedBox(height: 32),
              FadeInUp(
                delay: 300,
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
                      'Verificando estado del pago...',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('/orders'),
                child: const Text('Ir a mis pedidos'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountdown(PaymentSession session) {
    final isLow = session.countdownSeconds < 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isLow
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 20,
            color: isLow ? AppColors.error : AppColors.info,
          ),
          const SizedBox(width: 8),
          Text(
            session.countdownDisplay,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isLow ? AppColors.error : AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(PaymentState state) {
    final (IconData icon, Color color) = switch (state) {
      PaymentState.paid       => (Icons.check_circle_rounded, AppColors.success),
      PaymentState.failed     => (Icons.cancel_rounded, AppColors.error),
      PaymentState.expired    => (Icons.timer_off_rounded, AppColors.error),
      PaymentState.cancelled  => (Icons.cancel_rounded, AppColors.warning),
      PaymentState.processing => (Icons.hourglass_top_rounded, AppColors.warning),
      _                       => (Icons.payment_rounded, AppColors.info),
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 64, color: color),
    );
  }

  Widget _buildYappySection(Map<String, dynamic> instructions) {
    final phone = instructions['phone'] as String? ?? '';
    final reference = instructions['reference'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.phone_android, size: 40, color: AppColors.warning),
          const SizedBox(height: 12),
          Text(
            'Pagar con Yappy',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (phone.isNotEmpty)
            _YappyInfoRow(label: 'Teléfono', value: phone),
          if (reference.isNotEmpty)
            _YappyInfoRow(label: 'Referencia', value: reference),
          const SizedBox(height: 12),
          Text(
            'Abre tu app Yappy y realiza el pago usando la referencia indicada.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _YappyInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _YappyInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
