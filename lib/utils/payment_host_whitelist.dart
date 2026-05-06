/// Hosts the payment WebView is allowed to navigate to.
///
/// Anything else (ads, attacker iframes, redirect chains to phishing pages)
/// is blocked by [PaymentHostWhitelist.isAllowed].
class PaymentHostWhitelist {
  static const Set<String> hosts = {
    'app.tilopay.com',
    'tilopay.com',
    'apipagosbg.bgeneral.cloud',
    'banca.bgeneral.com',
    'bgeneral.com',
    'yappy.com.pa',
    'accounts.google.com',
  };

  /// Returns true if [url] points to one of the whitelisted hosts (or a
  /// subdomain of one), or to [bridgeOrigin] (our own checkout bridge).
  static bool isAllowed(String url, {String? bridgeOrigin}) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host;
    if (host.isEmpty) return false;

    if (bridgeOrigin != null) {
      final bridgeHost = Uri.tryParse(bridgeOrigin)?.host;
      if (bridgeHost != null && host == bridgeHost) return true;
    }

    return hosts.any((h) => host == h || host.endsWith('.$h'));
  }
}
