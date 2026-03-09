/// Payment processing states matching pagos-app transaction model
enum PaymentState {
  draft,      // Initial — order created, no payment action yet
  pending,    // Payment initiated, awaiting user action
  processing, // Gateway processing (WebView callback received or Yappy confirming)
  paid,       // Payment confirmed
  expired,    // Timeout (5 min countdown elapsed)
  cancelled,  // User cancelled
  failed;     // Gateway rejected

  bool get isTerminal => this == paid || this == failed || this == cancelled;
  bool get isRetryable => this == failed || this == expired || this == cancelled;
  bool get isWaiting => this == pending || this == processing;

  static PaymentState fromString(String? value) {
    return switch (value) {
      'paid' || 'completed' => PaymentState.paid,
      'processing'          => PaymentState.processing,
      'pending' || 'draft'  => PaymentState.pending,
      'expired'             => PaymentState.expired,
      'cancelled'           => PaymentState.cancelled,
      'failed'              => PaymentState.failed,
      _                     => PaymentState.draft,
    };
  }

  String get label => switch (this) {
    PaymentState.draft      => 'Pendiente de pago',
    PaymentState.pending    => 'Pago pendiente',
    PaymentState.processing => 'Procesando pago',
    PaymentState.paid       => 'Pago completado',
    PaymentState.expired    => 'Tiempo agotado',
    PaymentState.cancelled  => 'Pago cancelado',
    PaymentState.failed     => 'Pago fallido',
  };

  String get description => switch (this) {
    PaymentState.draft      => 'Completa el pago para confirmar tu compra.',
    PaymentState.pending    => 'Tu pedido ha sido creado. Completa el pago para confirmar tu compra.',
    PaymentState.processing => 'Estamos procesando tu pago. Esto puede tomar unos momentos.',
    PaymentState.paid       => 'Tu pago se ha procesado correctamente. Tu pedido está en camino.',
    PaymentState.expired    => 'El tiempo para completar el pago ha expirado.',
    PaymentState.cancelled  => 'El pago fue cancelado.',
    PaymentState.failed     => 'Hubo un problema con tu pago. Puedes intentar nuevamente.',
  };
}

/// Immutable session tracking payment state, retries, and countdown
class PaymentSession {
  final String orderId;
  final String paymentMethod; // 'tilopay', 'yappy', 'in_store'
  final String? paymentUrl;
  final PaymentState state;
  final int retryCount;
  final int countdownSeconds;
  final String? errorMessage;
  final Map<String, dynamic>? yappyInstructions;

  static const maxRetries = 5;
  static const countdownDuration = 300; // 5 minutes

  const PaymentSession({
    required this.orderId,
    required this.paymentMethod,
    this.paymentUrl,
    this.state = PaymentState.draft,
    this.retryCount = 0,
    this.countdownSeconds = countdownDuration,
    this.errorMessage,
    this.yappyInstructions,
  });

  bool get canRetry => retryCount < maxRetries && state.isRetryable;
  int get retriesRemaining => maxRetries - retryCount;
  bool get isCountdownActive => state.isWaiting && countdownSeconds > 0;

  String get countdownDisplay {
    final min = countdownSeconds ~/ 60;
    final sec = countdownSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  PaymentSession copyWith({
    PaymentState? state,
    int? retryCount,
    int? countdownSeconds,
    String? errorMessage,
    String? paymentUrl,
    Map<String, dynamic>? yappyInstructions,
  }) {
    return PaymentSession(
      orderId: orderId,
      paymentMethod: paymentMethod,
      paymentUrl: paymentUrl ?? this.paymentUrl,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      errorMessage: errorMessage ?? this.errorMessage,
      yappyInstructions: yappyInstructions ?? this.yappyInstructions,
    );
  }
}
