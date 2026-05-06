import 'package:flutter_test/flutter_test.dart';
import 'package:blackdog_app/utils/payment_host_whitelist.dart';

void main() {
  group('PaymentHostWhitelist.isAllowed', () {
    const bridge = 'https://api.blackdogpanama.com';

    test('allows whitelisted hosts', () {
      expect(PaymentHostWhitelist.isAllowed('https://app.tilopay.com/sdk'), isTrue);
      expect(PaymentHostWhitelist.isAllowed('https://yappy.com.pa/pay'), isTrue);
      expect(PaymentHostWhitelist.isAllowed('https://apipagosbg.bgeneral.cloud/api'), isTrue);
      expect(PaymentHostWhitelist.isAllowed('https://accounts.google.com/o/oauth2/auth'), isTrue);
    });

    test('allows subdomains of whitelisted hosts', () {
      expect(PaymentHostWhitelist.isAllowed('https://www.tilopay.com'), isTrue);
      expect(PaymentHostWhitelist.isAllowed('https://api.bgeneral.com/v2'), isTrue);
    });

    test('allows bridge origin host', () {
      expect(
        PaymentHostWhitelist.isAllowed(
          'https://api.blackdogpanama.com/checkout/result',
          bridgeOrigin: bridge,
        ),
        isTrue,
      );
    });

    test('blocks non-whitelisted hosts (attacker iframes / ads / phishing)', () {
      expect(PaymentHostWhitelist.isAllowed('https://evil.com/steal'), isFalse);
      expect(PaymentHostWhitelist.isAllowed('https://ads.google-analytics.com'), isFalse);
      expect(PaymentHostWhitelist.isAllowed('https://phishing-tilopay.com'), isFalse);
      expect(PaymentHostWhitelist.isAllowed('https://tilopay.com.attacker.io'), isFalse);
    });

    test('blocks lookalike hosts that suffix-match accidentally', () {
      // tilopay.com is whitelisted; "fake-tilopay.com" must NOT match.
      expect(PaymentHostWhitelist.isAllowed('https://fake-tilopay.com'), isFalse);
      // bgeneral.com is whitelisted; "evilbgeneral.com" must NOT match.
      expect(PaymentHostWhitelist.isAllowed('https://evilbgeneral.com'), isFalse);
    });

    test('blocks malformed URLs', () {
      expect(PaymentHostWhitelist.isAllowed(''), isFalse);
      expect(PaymentHostWhitelist.isAllowed('not a url'), isFalse);
      expect(PaymentHostWhitelist.isAllowed('javascript:alert(1)'), isFalse);
    });

    test('blocks data: and file: schemes', () {
      expect(PaymentHostWhitelist.isAllowed('data:text/html,<script>'), isFalse);
      expect(PaymentHostWhitelist.isAllowed('file:///etc/passwd'), isFalse);
    });
  });
}
