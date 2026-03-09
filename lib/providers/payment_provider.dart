import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payment_state.dart';
import 'service_providers.dart';

/// Provider family keyed by orderId — each order gets its own payment session
final paymentProvider =
    StateNotifierProvider.family<PaymentNotifier, PaymentSession, PaymentSessionParams>(
  (ref, params) => PaymentNotifier(ref, params),
);

/// Params to initialize a payment session
class PaymentSessionParams {
  final String orderId;
  final String paymentMethod;
  final String? paymentUrl;

  const PaymentSessionParams({
    required this.orderId,
    required this.paymentMethod,
    this.paymentUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentSessionParams &&
          orderId == other.orderId &&
          paymentMethod == other.paymentMethod;

  @override
  int get hashCode => orderId.hashCode ^ paymentMethod.hashCode;
}

class PaymentNotifier extends StateNotifier<PaymentSession> {
  final Ref _ref;
  Timer? _pollTimer;
  Timer? _countdownTimer;

  PaymentNotifier(this._ref, PaymentSessionParams params)
      : super(PaymentSession(
          orderId: params.orderId,
          paymentMethod: params.paymentMethod,
          paymentUrl: params.paymentUrl,
        ));

  /// Start polling + countdown (call when payment is initiated)
  void startPayment() {
    if (state.state == PaymentState.paid) return;
    state = state.copyWith(
      state: PaymentState.pending,
      countdownSeconds: PaymentSession.countdownDuration,
    );
    _startPolling();
    _startCountdown();
  }

  /// Retry payment (resets countdown, increments retry count)
  void retry() {
    if (!state.canRetry) return;
    _stopTimers();
    state = state.copyWith(
      state: PaymentState.pending,
      retryCount: state.retryCount + 1,
      countdownSeconds: PaymentSession.countdownDuration,
      errorMessage: null,
    );
    _startPolling();
    _startCountdown();
  }

  /// Transition to processing (e.g., WebView detected callback)
  void markProcessing() {
    if (state.state.isTerminal) return;
    state = state.copyWith(state: PaymentState.processing);
    // Ensure polling is running to confirm the payment
    if (_pollTimer == null || !_pollTimer!.isActive) {
      _startPolling();
    }
  }

  /// Transition to failed
  void markFailed([String? message]) {
    _stopTimers();
    state = state.copyWith(
      state: PaymentState.failed,
      errorMessage: message,
    );
  }

  /// Transition to cancelled
  void markCancelled() {
    _stopTimers();
    state = state.copyWith(state: PaymentState.cancelled);
  }

  /// Set Yappy instructions from API
  void setYappyInstructions(Map<String, dynamic> instructions) {
    state = state.copyWith(yappyInstructions: instructions);
  }

  // ── Polling ──────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkStatus(),
    );
    // Check immediately too
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (state.state.isTerminal) {
      _stopTimers();
      return;
    }

    try {
      final api = _ref.read(apiServiceProvider);
      final result = await api.checkPaymentStatus(state.orderId);
      final serverState = PaymentState.fromString(
        result['payment_status'] as String?,
      );

      if (serverState == PaymentState.paid) {
        _stopTimers();
        state = state.copyWith(state: PaymentState.paid);
      } else if (serverState == PaymentState.failed) {
        _stopTimers();
        state = state.copyWith(state: PaymentState.failed);
      } else if (serverState == PaymentState.processing &&
          state.state == PaymentState.pending) {
        state = state.copyWith(state: PaymentState.processing);
      }
    } catch (_) {
      // Silently continue polling
    }
  }

  // ── Countdown ────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.state.isTerminal) {
        _stopTimers();
        return;
      }

      final next = state.countdownSeconds - 1;
      if (next <= 0) {
        _stopTimers();
        state = state.copyWith(
          state: PaymentState.expired,
          countdownSeconds: 0,
          errorMessage: state.canRetry
              ? 'Tiempo agotado. Te quedan ${state.retriesRemaining - 1} intentos.'
              : 'Se agotaron los intentos disponibles.',
        );
      } else {
        state = state.copyWith(countdownSeconds: next);
      }
    });
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
