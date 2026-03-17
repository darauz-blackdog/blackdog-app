# Payment SDK Integration — Tilopay SDK V2 + Yappy Button V2

**Date:** 2026-03-17
**Status:** Approved
**Scope:** Replace WebView redirect flows with embedded SDK payment forms

## Problem

The current payment flow redirects users to external pages (Tilopay gateway via WebView, manual Yappy polling). This causes:
- Slow UX (WebView loads external pages)
- No visual consistency (Tilopay's generic page vs Black Dog branding)
- Fragile polling for Yappy (queries transaction history hoping to match amounts)
- Multiple screens for a single concern (TilopayPaymentScreen, YappyPaymentScreen, PaymentStatusScreen)

## Solution

Replace all payment screens with a single `PaymentScreen` that loads an HTML Bridge page hosted on the VPS. The bridge page embeds the official Tilopay SDK V2 (card form) and Yappy Button V2 (web component), styled with Black Dog branding. Communication between Flutter and JS happens via `JavaScriptChannel`.

## Architecture

```
Flutter App
  └─ PaymentScreen
      └─ WebView (invisible chrome, fullscreen)
          └─ pay.blackdogpanama.com/checkout
              ├─ Tilopay SDK V2 (card form)
              └─ Yappy Button V2 (web component)
      └─ JavaScriptChannel "FlutterBridge"
          ← success | error | cancel | loading | ready

Backend API (Express)
  ├─ POST /api/payments/sdk/init-tilopay → SDK token
  ├─ POST /api/payments/yappy/create-order → validate + create
  ├─ GET  /api/payments/yappy/ipn → IPN callback
  └─ GET  /api/payments/tilopay/return → redirect handler (adapted for SDK)
```

## HTML Bridge Page

**Location:** `blackdog-api/public/checkout/index.html` served as static file by Express/Nginx.

**Data passing strategy:** The bridge page receives ONLY non-sensitive display data via URL params (`method`, `amount`, `order_number`). Sensitive data (SDK tokens, JWT, PII) is passed via `postMessage` from Flutter after the page loads. This avoids tokens in URL/logs/history.

**URL params (non-sensitive only):**
- `method` — `tilopay` or `yappy`
- `amount`, `currency`, `order_number`

**Post-load initialization via Flutter → JS postMessage:**
```dart
// Flutter sends config after WebView loads
_controller.runJavascript('''
  initPayment(${jsonEncode({
    'method': 'tilopay',
    'token': sdkToken,
    'amount': 10.01,
    'currency': 'USD',
    'orderNumber': 'ORD-abc123',
    'email': 'cliente@email.com',
    'firstName': 'Juan',
    'lastName': 'Perez',
    'redirectUrl': 'https://api.blackdogpanama.com/api/payments/tilopay/return?source=sdk',
  })})
''');
```

**Script loading:** Only the relevant SDK is loaded based on `method` param to avoid namespace conflicts. The bridge conditionally includes either the Tilopay SDK or the Yappy CDN, never both.

**Tilopay form:**
- Loads `https://app.tilopay.com/sdk/v2/sdk_tpay.min.js` (only when method=tilopay)
- Required HTML structure: `.payFormTilopay` with `#tlpy_cc_number`, `#tlpy_cc_expiration_date`, `#tlpy_cvv`, `#tlpy_payment_method`, `#responseTilopay`
- Calls `Tilopay.Init()` with params received via `initPayment()`
- On `Tilopay.startPayment()` completion, SDK redirects to return URL with `source=sdk` appended
- Backend return endpoint detects `source=sdk` and responds with JSON instead of redirect
- 3DS challenges resolve within `#responseTilopay` div. WebView navigation delegate allows all domains during payment processing (3DS may redirect to bank verification pages).
- JS reads response and posts to FlutterBridge

**Yappy form:**
- Loads CDN: `https://bt-cdn.yappy.cloud/v1/cdn/web-component-btn-yappy.js` (only when method=yappy)
- Shows phone input + `<yappy-button theme="brand">`
- `eventClick` → JS posts `{type:'yappy_click', data:{phone}}` to FlutterBridge
- **Flutter intercepts**, calls `POST /api/payments/yappy/create-order` natively with JWT auth
- Flutter passes result back to JS via `evaluateJavascript('setYappyPayment(${jsonEncode(data)})')`
- JS sets `yappyButton.eventPayment = data`
- `eventSuccess` → posts to FlutterBridge
- `eventError` → posts error to FlutterBridge
- `eventCancel` / timeout → posts `{type:'cancel'}` to FlutterBridge

This avoids the bridge needing the JWT — Flutter handles all authenticated API calls natively.

**Styling:** Dark theme matching Black Dog app — `#1A1A2E` background, `#F7B104` accents, Montserrat font, rounded inputs.

**CSP headers:** Nginx serves the bridge with `Content-Security-Policy: script-src 'self' https://app.tilopay.com https://bt-cdn.yappy.cloud https://bt-cdn-uat.yappycloud.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;`

**JS → Flutter communication:**
```javascript
window.FlutterBridge.postMessage(JSON.stringify({
  type: 'success' | 'error' | 'cancel' | 'loading' | 'ready' | 'yappy_click',
  data: { ... }
}));
```

**Message types and data schema:**
| Type | Data fields | When |
|------|-------------|------|
| `ready` | `{}` | Bridge page loaded, awaiting `initPayment()` |
| `loading` | `{}` | SDK initializing |
| `success` | `{order_id, txn_id?}` | Payment confirmed |
| `error` | `{code, message}` | Payment failed (gateway code + human message) |
| `cancel` | `{}` | User cancelled or Yappy timeout |
| `yappy_click` | `{phone}` | Yappy button clicked, Flutter must call create-order API |

## Flutter — PaymentScreen

**Single screen** replaces TilopayPaymentScreen, YappyPaymentScreen, PaymentStatusScreen.

**Constructor:**
```dart
PaymentScreen({
  required String orderId,
  required String paymentMethod,  // 'tilopay' | 'yappy'
  required double amount,
  String currency = 'USD',
})
```

User PII (`email`, `firstName`, `lastName`) is read from `profileProvider` inside the screen. Yappy `phone` is entered by the user inside the bridge HTML. This keeps the constructor lean and avoids passing PII through navigation params.

**States:**
- `loading` — WebView loading + token fetch (tilopay). Shows Black Dog spinner.
- `ready` — WebView visible. Native header overlay: "Pago seguro" + close button.
- `processing` — Native overlay with spinner + "Procesando pago..." Blocks interaction.
- `success` — Native animation (reuses PaymentResultView) + "Ver pedido" / "Seguir comprando"
- `error` — Error message + "Reintentar" (reloads WebView) or "Cancelar"

**Back button handling:**
- `ready` → confirm dialog "Cancelar el pago?" → navigate to order detail
- `processing` → blocked
- `success` → navigate to order detail

**Fallback polling:** If FlutterBridge doesn't receive a message within 60s after entering `processing`, Flutter polls `GET /api/payments/status/:order_id` (generic endpoint, works for both Tilopay and Yappy) every 5s as backup. This endpoint checks the order's `payment_status` field in Supabase which gets updated by both Tilopay return/webhook and Yappy IPN.

**WebView navigation:** During payment, the WebView allows navigation to any domain (3DS verification may redirect to Visa/Mastercard/bank domains). The whitelist is only enforced for the initial page load (`pay.blackdogpanama.com`).

**User data sourcing:** `email`, `firstName`, `lastName` come from `profileProvider`. `phone` for Yappy is entered by the user inside the bridge HTML, not passed from Flutter.

## Backend — New Endpoints

### POST /api/payments/sdk/init-tilopay
Auth required. Generates SDK token for Tilopay.Init().

Request: `{ order_id: string }`
Response: `{ token: string, order_number: string, amount: number, currency: "USD" }`

- Validates order exists, belongs to user, status is `pending_payment`
- Calls Tilopay `GetTokenSdk` API endpoint
- Returns token for Flutter to pass to HTML Bridge

### POST /api/payments/yappy/create-order
Auth required. Orchestrates Yappy V2 two-step flow.

Request: `{ order_id: string, phone: string }`
Response: `{ transactionId: string, token: string, documentName: string }`

- Validates order and status
- Step 1: `POST apipagosbg.bgeneral.cloud/payments/validate/merchant` with merchantId + domain
- Step 2: `POST apipagosbg.bgeneral.cloud/payments/payment-wc` with auth token, orderId (max 15 chars), phone, amounts, ipnUrl
- Stores payment_reference on order
- Returns 3 fields needed by `yappyButton.eventPayment`

### GET /api/payments/yappy/ipn
Public endpoint. Receives Yappy IPN callback.

Query params: `orderId`, `Hash`, `status` (E|R|C|X), `domain`

- Verifies Hash using HMAC-SHA256 with YAPPY_SECRET_KEY
- `E` (Ejecutado): order → confirmed, payment_status → paid, create tracking entry, notify Odoo
- `R` (Rechazado): payment_status → failed
- `C` (Cancelado): payment_status → cancelled
- `X` (Expirado): payment_status → failed

### New: GET /api/payments/status/:order_id
Auth required. Generic payment status check (replaces Tilopay-specific endpoint for polling).

Response: `{ payment_status: string, order_status: string }`

- Simply reads `payment_status` and `status` from the order in Supabase
- Works for both Tilopay and Yappy — backend updates these fields via return URL (Tilopay) or IPN (Yappy)
- Used as fallback polling by Flutter when bridge is unresponsive

### Modified: GET /api/payments/tilopay/return
Existing endpoint adapted for SDK flow.

- If query contains `source=sdk`: respond with JSON `{ success: true, order_id }` instead of HTTP redirect
- JS in the HTML Bridge catches this response and posts to FlutterBridge
- Non-SDK requests continue to work as before (backward compatible)

## Environment Variables (new)

```env
# Yappy Botón de Pago V2
YAPPY_MERCHANT_ID=<from yappy comercial>
YAPPY_SECRET_KEY=<from yappy comercial>
YAPPY_DOMAIN=https://blackdogpanama.com
YAPPY_IPN_URL=https://api.blackdogpanama.com/api/payments/yappy/ipn
YAPPY_API_URL=https://apipagosbg.bgeneral.cloud

# Payment HTML Bridge
PAYMENT_BRIDGE_URL=https://pay.blackdogpanama.com/checkout
```

## Files

### Create
| File | Purpose |
|------|---------|
| `blackdog-api/public/checkout/index.html` | HTML Bridge with Tilopay + Yappy forms, Black Dog styling |
| `blackdog-api/src/services/yappy-v2.service.ts` | Yappy Button V2 service (validate, create order, verify IPN) |
| `blackdog-api/src/routes/yappy-v2.routes.ts` | create-order + IPN endpoints |
| `blackdog-app/lib/screens/checkout/payment_screen.dart` | Unified payment screen |

### Modify
| File | Change |
|------|--------|
| `blackdog-api/src/routes/payments.routes.ts` | Add `POST /sdk/init-tilopay`, serve static HTML |
| `blackdog-api/src/services/tilopay.service.ts` | Add `getSDKToken()`, adapt return for JSON response |
| `blackdog-api/.env` | New Yappy V2 + bridge vars |
| `blackdog-app/lib/screens/checkout/order_confirmation_screen.dart` | Navigate to new PaymentScreen |
| `blackdog-app/lib/config/routes.dart` | Single `/payment/:id` route |
| `blackdog-app/lib/providers/payment_provider.dart` | Simplify: listen to bridge, fallback polling only |
| `blackdog-app/lib/services/api_service.dart` | Add `initTilopaySDK()`, `createYappyOrder()`, `getPaymentStatus()`. Remove old `createYappyPayment()`, `getYappyInstructions()`, rename `checkPaymentStatus()` to use generic endpoint |

### Delete
| File | Reason |
|------|--------|
| `blackdog-app/lib/screens/checkout/tilopay_payment_screen.dart` | Replaced by PaymentScreen |
| `blackdog-app/lib/screens/checkout/yappy_payment_screen.dart` | Replaced by PaymentScreen |
| `blackdog-app/lib/screens/checkout/payment_status_screen.dart` | No longer needed |
| `blackdog-app/lib/widgets/payment_countdown.dart` | Countdown in web component |

### Keep unchanged
- `payment_result_view.dart` — reused for success/error animations
- `order_detail_screen.dart` — "Pagar ahora" points to new route
- `models/order.dart` — no schema changes
- `models/payment_state.dart` — simplified but same interface

## End-to-End Flows

### Tilopay (card payment)
1. Checkout creates order (pending_payment)
2. Flutter calls `POST /api/payments/sdk/init-tilopay` → gets token
3. Flutter opens WebView: `pay.blackdogpanama.com/checkout?method=tilopay&token=X&...`
4. HTML loads SDK, calls `Tilopay.Init({token, amount, ...})`
5. User fills card, taps "Pagar"
6. JS calls `Tilopay.startPayment()`
7. 3DS resolves in `#responseTilopay` if needed
8. SDK redirects to return URL → backend updates order → responds JSON
9. JS posts `{type:'success'}` to FlutterBridge
10. Flutter shows success animation

### Yappy
1. Checkout creates order (pending_payment)
2. Flutter opens WebView: `pay.blackdogpanama.com/checkout?method=yappy&amount=Y&order_number=X`
3. Flutter sends display data via `initPayment()` (amount, order number)
4. HTML loads Yappy CDN, shows phone input + button
5. User enters phone, taps Yappy button
6. `eventClick` → JS posts `{type:'yappy_click', data:{phone}}` to FlutterBridge
7. **Flutter** calls `POST /api/payments/yappy/create-order` natively (with JWT auth)
8. Flutter passes result back to JS: `setYappyPayment({transactionId, token, documentName})`
9. JS sets `yappyButton.eventPayment = {...}`
10. Yappy shows modal with countdown inside web component
11. User confirms in Yappy app
12. Yappy sends IPN → `GET /api/payments/yappy/ipn?status=E`
13. Backend updates order → confirmed, payment_status → paid
14. Web component fires `eventSuccess` → JS posts `{type:'success'}` to FlutterBridge
15. Flutter shows success animation

### Fallbacks
- WebView fails to load (15s timeout) → Flutter shows error + "Reintentar"
- Bridge doesn't respond after processing (60s) → Flutter polls `GET /api/payments/status/:order_id` every 5s (generic, checks Supabase order.payment_status)
- User closes app mid-payment → order stays pending_payment, retry from "Mis Pedidos"
- Network loss mid-payment → WebView shows browser offline state, Flutter detects via bridge silence and offers retry
- Yappy user doesn't confirm within 5 min → web component fires timeout, bridge sends `{type:'cancel'}`, Flutter shows retry option

## Testing

1. Create test product in Odoo ($0.01) — already done (id: 22322)
2. Test Tilopay flow with test card numbers (Tilopay sandbox)
3. Test Yappy flow with UAT environment (`api-comecom-uat.yappycloud.com` + UAT CDN)
4. Verify IPN callback with manual curl
5. Verify fallback polling when bridge is unresponsive
6. Test back button behavior in all states
7. Run Maestro E2E test for complete purchase flow
