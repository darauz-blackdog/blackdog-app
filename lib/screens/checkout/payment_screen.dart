import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/env.dart';
import '../../providers/orders_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';

/// Unified payment screen that embeds the HTML Bridge for Tilopay SDK V2
/// and Yappy Button V2. Communicates via JavaScriptChannel 'FlutterBridge'.
///
/// Required params: orderId, paymentMethod ('tilopay' | 'yappy'), amount.
class PaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String paymentMethod;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.paymentMethod,
    this.amount = 0,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  WebViewController? _controller;
  bool _sdkInited = false;
  bool _processing = false;
  bool _initError = false;
  String? _errorMessage;
  String? _orderNumber;
  Timer? _fallbackTimer;
  Timer? _pollTimer;

  /// Base URL of the VPS (without /api suffix)
  String get _vpsBase =>
      Env.apiBaseUrl.replaceAll(RegExp(r'/api$'), '');

  String get _bridgeUrl =>
      '$_vpsBase/checkout/?method=${widget.paymentMethod}'
      '&amount=${widget.amount.toStringAsFixed(2)}'
      '${_orderNumber != null ? "&order_number=$_orderNumber" : ""}';

  @override
  void initState() {
    super.initState();
    _initOrder();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Step 1: fetch order number + SDK token (for tilopay) ──────

  Future<void> _initOrder() async {
    try {
      final api = ref.read(apiServiceProvider);

      // For Tilopay: get SDK token first (validates order is pending_payment)
      if (widget.paymentMethod == 'tilopay') {
        final data = await api.initTilopaySDK(widget.orderId);
        _orderNumber = data['order_number'] as String?;
        _buildWebView(sdkToken: data['token'] as String?);
      } else {
        // For Yappy: just need the order number from the order detail
        final orderAsync = ref.read(orderDetailProvider(widget.orderId));
        _orderNumber = orderAsync.valueOrNull?.odooOrderName;
        _buildWebView();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = true;
          _errorMessage = e.toString().replaceAll('DioException', 'Error');
        });
      }
    }
  }

  // ── Step 2: build WebView with the bridge URL ─────────────────

  void _buildWebView({String? sdkToken}) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          if (!mounted) return;
          _callInitPayment(sdkToken: sdkToken);
        },
      ))
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _onBridgeMessage,
      )
      ..loadRequest(Uri.parse(_bridgeUrl));

    if (mounted) setState(() {}); // trigger rebuild to show WebViewWidget
  }

  // ── Step 3: inject config after page loads ────────────────────

  Future<void> _callInitPayment({String? sdkToken}) async {
    if (_sdkInited) return;
    _sdkInited = true;

    try {
      final profile = await ref.read(profileProvider.future);
      final fullName = profile['full_name'] as String? ?? '';
      final nameParts = fullName.split(' ');

      final config = <String, dynamic>{
        'order_number': _orderNumber ?? widget.orderId.substring(0, 8).toUpperCase(),
        'amount': widget.amount,
        'currency': 'USD',
        'first_name': nameParts.isNotEmpty ? nameParts.first : 'Cliente',
        'last_name': nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
        'email': profile['email'] as String? ?? '',
        'phone': profile['phone'] as String? ?? '',
        'bill_to_address': 'Panama City',
        'redirect_url': '${Env.apiBaseUrl}/payments/tilopay/return?source=sdk',
        if (sdkToken != null) 'token': sdkToken,
      };

      final configJson = jsonEncode(config).replaceAll("'", "\\'");
      await _controller?.runJavaScript("initPayment($configJson)");
    } catch (e) {
      // Non-fatal — bridge will show its own loading error
    }
  }

  // ── Bridge message handler ─────────────────────────────────────

  void _onBridgeMessage(JavaScriptMessage message) {
    if (!mounted) return;
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = data['type'] as String? ?? '';

    switch (type) {
      case 'ready':
        // Bridge loaded and payment form is ready — nothing to do
        break;

      case 'processing':
        setState(() => _processing = true);
        _startFallbackTimer();
        break;

      case 'yappy_click':
        _handleYappyClick(data['phone'] as String? ?? '');
        break;

      case 'success':
        _fallbackTimer?.cancel();
        _pollTimer?.cancel();
        _handleSuccess();
        break;

      case 'error':
        _fallbackTimer?.cancel();
        setState(() {
          _processing = false;
          _errorMessage = data['message'] as String?;
        });
        break;

      case 'cancel':
        _fallbackTimer?.cancel();
        if (mounted) context.pop();
        break;
    }
  }

  // ── Yappy: call API natively, pass result to JS ───────────────

  Future<void> _handleYappyClick(String phone) async {
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.createYappyV2Order(widget.orderId, phone);
      final json = jsonEncode(result).replaceAll("'", "\\'");
      await _controller?.runJavaScript("setYappyPayment($json)");
    } catch (e) {
      final msg = e.toString().replaceAll("'", " ").replaceAll('"', ' ');
      await _controller?.runJavaScript("setYappyError('$msg')");
    }
  }

  // ── Success: invalidate order cache and navigate ──────────────

  void _handleSuccess() {
    ref.invalidate(orderDetailProvider(widget.orderId));
    if (!mounted) return;
    context.go('/orders/${widget.orderId}');
  }

  // ── Fallback polling (if bridge is silent for 60s) ────────────

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted) return;
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        try {
          final api = ref.read(apiServiceProvider);
          final result = await api.getPaymentStatus(widget.orderId);
          final payStatus = result['payment_status'] as String?;
          if (payStatus == 'paid') {
            _pollTimer?.cancel();
            _handleSuccess();
          }
        } catch (_) {}
      });
    });
  }

  // ── UI ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pago seguro 🔒'),
          leading: _processing
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.pop(),
                ),
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          children: [
            if (_initError)
              _buildError()
            else if (_controller != null)
              WebViewWidget(controller: _controller!)
            else
              const Center(child: CircularProgressIndicator()),

            // Processing overlay
            if (_processing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Procesando pago...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(
            'No se pudo iniciar el pago',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _initError = false;
                _sdkInited = false;
                _controller = null;
              });
              _initOrder();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
