import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/payment_state.dart';
import '../../providers/payment_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/payment_countdown.dart';
import '../../widgets/payment_result_view.dart';

class TilopayPaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String paymentUrl;
  final String? orderName;
  final double? amount;

  const TilopayPaymentScreen({
    super.key,
    required this.orderId,
    required this.paymentUrl,
    this.orderName,
    this.amount,
  });

  @override
  ConsumerState<TilopayPaymentScreen> createState() =>
      _TilopayPaymentScreenState();
}

class _TilopayPaymentScreenState extends ConsumerState<TilopayPaymentScreen> {
  WebViewController? _webViewController;
  bool _webViewLoading = true;
  bool _showWebView = false;

  late final PaymentSessionParams _params;

  @override
  void initState() {
    super.initState();
    _params = PaymentSessionParams(
      orderId: widget.orderId,
      paymentMethod: 'tilopay',
      paymentUrl: widget.paymentUrl,
    );
  }

  void _openWebView() {
    if (kIsWeb) {
      launchUrl(
        Uri.parse(widget.paymentUrl),
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    final notifier = ref.read(paymentProvider(_params).notifier);
    notifier.startPayment();

    // Only load whitelisted payment domains
    final uri = Uri.parse(widget.paymentUrl);
    const allowedDomains = ['tilopay.com', 'tilopay.cr'];
    if (!allowedDomains.any((d) => uri.host == d || uri.host.endsWith('.$d'))) {
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
            final url = request.url.toLowerCase();
            final navUri = Uri.tryParse(request.url);

            // Intercept our return URL — Tilopay redirects here after payment
            if (url.contains('tilopay/return') ||
                url.contains('api.blackdogpanama.com') ||
                url.contains('blackdogapp://')) {
              // Parse the code param: code=1 means approved
              final code = navUri?.queryParameters['code'];
              if (code == '1') {
                notifier.markProcessing();
              } else {
                final desc = navUri?.queryParameters['description'] ?? 'El pago no se completó.';
                notifier.markFailed(desc);
              }
              setState(() => _showWebView = false);
              return NavigationDecision.prevent;
            }

            // Whitelist: only allow Tilopay domains + our API domain
            if (navUri != null) {
              final host = navUri.host;
              const allowed = ['tilopay.com', 'tilopay.cr', 'blackdogpanama.com'];
              if (!allowed.any((d) => host == d || host.endsWith('.$d'))) {
                return NavigationDecision.prevent;
              }
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(uri);

    setState(() {
      _webViewController = controller;
      _showWebView = true;
      _webViewLoading = true;
    });
  }

  void _retry() {
    ref.read(paymentProvider(_params).notifier).retry();
    _openWebView();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(paymentProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: Text(_showWebView ? 'Pago seguro' : 'Pagar con tarjeta'),
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
      body: _showWebView ? _buildWebView() : _buildContent(session),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        if (_webViewController != null)
          WebViewWidget(controller: _webViewController!),
        if (_webViewLoading)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildContent(PaymentSession session) {
    // Terminal success
    if (session.state == PaymentState.paid) {
      return ResponsiveCenter(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.padding(context)),
          child: PaymentResultView(
            isSuccess: true,
            title: '¡Pago completado!',
            subtitle: 'Tu pago se ha procesado correctamente.',
            orderName: widget.orderName,
            paymentMethod: 'tilopay',
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

    // Terminal failure (no retries left)
    if (session.state.isRetryable && !session.canRetry) {
      return ResponsiveCenter(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.padding(context)),
          child: PaymentResultView(
            isSuccess: false,
            title: session.state.label,
            subtitle: 'Se agotaron los intentos disponibles.',
            orderName: widget.orderName,
            paymentMethod: 'tilopay',
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

    return ResponsiveCenter(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.padding(context)),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Countdown (when payment started)
            if (session.isCountdownActive) ...[
              FadeInUp(
                delay: 0,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: PaymentCountdown(session: session),
              ),
              const SizedBox(height: 24),
            ],

            // Status icon (when not counting down)
            if (!session.isCountdownActive)
              FadeInUp(
                delay: 0,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    size: 64,
                    color: AppColors.info,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Title
            FadeInUp(
              delay: 100,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Text(
                session.state == PaymentState.processing
                    ? 'Procesando pago...'
                    : session.state.isRetryable
                        ? session.state.label
                        : 'Pago con tarjeta',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            FadeInUp(
              delay: 150,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Text(
                session.errorMessage ??
                    (session.state == PaymentState.processing
                        ? 'Verificando tu pago con el banco...'
                        : 'Serás redirigido a Tilopay para completar tu pago de forma segura.'),
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
              const SizedBox(height: 16),
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

            // Pay button (initial state or draft)
            if (session.state == PaymentState.draft ||
                session.state == PaymentState.pending)
              FadeInUp(
                delay: 200,
                offset: 20,
                duration: const Duration(milliseconds: 500),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openWebView,
                    icon: const Icon(Icons.lock_rounded, size: 18),
                    label: Text(
                      session.state == PaymentState.draft
                          ? 'Pagar ahora'
                          : 'Continuar pago',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),

            // Retry button
            if (session.canRetry)
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

            // Processing indicator
            if (session.state == PaymentState.processing) ...[
              const SizedBox(height: 24),
              FadeInUp(
                delay: 250,
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
            ],

            const SizedBox(height: 24),

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
                    'Procesado por Tilopay',
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
}
