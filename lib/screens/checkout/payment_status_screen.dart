import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
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
  String _status = 'pending'; // pending, processing, completed, failed
  Timer? _pollTimer;
  bool _polling = false;
  Map<String, dynamic>? _yappyInstructions;

  // WebView
  WebViewController? _webViewController;
  bool _webViewLoading = true;
  bool _showWebView = false;

  @override
  void initState() {
    super.initState();
    if (widget.paymentMethod == 'yappy') {
      _loadYappyInstructions();
    }
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    if (_polling || _status == 'completed') return;
    _polling = true;

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.checkTilopayStatus(widget.orderId);
      final paymentStatus =
          result['payment_status'] as String? ?? 'pending';

      if (mounted) {
        setState(() {
          if (paymentStatus == 'paid' || paymentStatus == 'completed') {
            _status = 'completed';
            _showWebView = false;
            _pollTimer?.cancel();
          } else if (paymentStatus == 'failed' ||
              paymentStatus == 'cancelled') {
            _status = 'failed';
            _showWebView = false;
            _pollTimer?.cancel();
          } else if (paymentStatus == 'processing') {
            _status = 'processing';
          }
        });
      }
    } catch (_) {
      // Silently continue polling
    } finally {
      _polling = false;
    }
  }

  Future<void> _loadYappyInstructions() async {
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.getYappyInstructions(widget.orderId);
      if (mounted) {
        setState(() => _yappyInstructions = result);
      }
    } catch (_) {}
  }

  void _openPayment() {
    if (widget.paymentUrl == null) return;

    // WebView not supported on web — fall back to url_launcher
    if (kIsWeb) {
      final uri = Uri.parse(widget.paymentUrl!);
      launchUrl(uri, mode: LaunchMode.externalApplication);
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
            // Detect callback/return URLs from payment gateway
            final url = request.url.toLowerCase();
            if (url.contains('payment/success') ||
                url.contains('payment/callback') ||
                url.contains('status=approved')) {
              setState(() {
                _status = 'processing';
                _showWebView = false;
              });
              return NavigationDecision.prevent;
            }
            if (url.contains('payment/cancel') ||
                url.contains('payment/failed') ||
                url.contains('status=declined')) {
              setState(() {
                _status = 'failed';
                _showWebView = false;
              });
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

  @override
  Widget build(BuildContext context) {
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
      body: _showWebView ? _buildWebView() : _buildStatusView(),
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

  Widget _buildStatusView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Status icon
          FadeInUp(
            delay: 0,
            offset: 20,
            duration: const Duration(milliseconds: 500),
            child: _buildStatusIcon(),
          ),
          const SizedBox(height: 24),

          // Status text
          FadeInUp(
            delay: 100,
            offset: 20,
            duration: const Duration(milliseconds: 500),
            child: Text(
              _statusTitle,
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
              _statusDescription,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // Yappy instructions
          if (widget.paymentMethod == 'yappy' &&
              _yappyInstructions != null)
            FadeInUp(
              delay: 200,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: _buildYappySection(),
            ),

          // Pay button (Tilopay) — opens WebView
          if (widget.paymentUrl != null && _status == 'pending')
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

          // Completed/Failed actions
          if (_status == 'completed' || _status == 'failed') ...[
            const SizedBox(height: 24),
            FadeInUp(
              delay: 300,
              offset: 20,
              duration: const Duration(milliseconds: 500),
              child: Column(
                children: [
                  if (_status == 'failed' && widget.paymentUrl != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openPayment,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Intentar de nuevo'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
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
          if (_status == 'pending' || _status == 'processing') ...[
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
    );
  }

  Widget _buildStatusIcon() {
    final (IconData icon, Color color) = switch (_status) {
      'completed' => (Icons.check_circle_rounded, AppColors.success),
      'failed' => (Icons.cancel_rounded, AppColors.error),
      'processing' => (Icons.hourglass_top_rounded, AppColors.warning),
      _ => (Icons.payment_rounded, AppColors.info),
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

  String get _statusTitle => switch (_status) {
        'completed' => '¡Pago completado!',
        'failed' => 'Pago fallido',
        'processing' => 'Procesando pago',
        _ => 'Pago pendiente',
      };

  String get _statusDescription => switch (_status) {
        'completed' =>
          'Tu pago se ha procesado correctamente. Tu pedido está en camino.',
        'failed' =>
          'Hubo un problema con tu pago. Puedes intentar nuevamente.',
        'processing' =>
          'Estamos procesando tu pago. Esto puede tomar unos momentos.',
        _ =>
          'Tu pedido ha sido creado. Completa el pago para confirmar tu compra.',
      };

  Widget _buildYappySection() {
    final phone = _yappyInstructions?['phone'] as String? ?? '';
    final reference = _yappyInstructions?['reference'] as String? ?? '';

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
