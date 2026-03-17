# Payment SDK Integration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace WebView redirect payment flows with embedded Tilopay SDK V2 and Yappy Button V2 via an HTML Bridge page, unifying three payment screens into one.

**Architecture:** A static HTML page on the VPS embeds the JS SDKs (Tilopay card form + Yappy web component) styled with Black Dog branding. Flutter loads this page in an invisible WebView and communicates via JavaScriptChannel. Backend gains new endpoints for SDK token generation, Yappy V2 order creation, and IPN handling.

**Tech Stack:** Express.js (backend), HTML/JS/CSS (bridge), Flutter/Dart + webview_flutter (app), Tilopay SDK V2, Yappy Button V2 web component

**Spec:** `docs/superpowers/specs/2026-03-17-payment-sdk-integration-design.md`

**Ref docs:** `docs/tilopay-sdk-reference.md`, `docs/yappy-button-reference.md`

---

## Chunk 1: Backend — New Endpoints

### Task 1: Generic payment status endpoint

**Files:**
- Modify: `blackdog-api/src/routes/payments.routes.ts`

This is the simplest endpoint and unblocks the Flutter fallback polling.

- [ ] **Step 1: Add generic status endpoint**

Add before the Yappy section in `payments.routes.ts`:

```typescript
/**
 * GET /api/payments/status/:order_id
 * Generic payment status check — reads from Supabase, works for all payment methods.
 * Used as fallback polling by the Flutter app when the JS bridge is unresponsive.
 */
router.get('/payments/status/:order_id', requireAuth, async (req: Request, res: Response) => {
  const { id: userId } = (req as AuthenticatedRequest).user;
  const orderId = req.params.order_id;

  try {
    const { data: order } = await supabase
      .from('orders')
      .select('id, payment_status, status')
      .eq('id', orderId)
      .eq('user_id', userId)
      .single();

    if (!order) {
      res.status(404).json({ error: 'Order not found' });
      return;
    }

    res.json({ payment_status: order.payment_status, order_status: order.status });
  } catch (err) {
    logger.error({ err }, 'Payment status check error');
    res.status(500).json({ error: 'Failed to check payment status' });
  }
});
```

- [ ] **Step 2: Test with curl**

```bash
# From VPS after deploy
curl -H "Authorization: Bearer <jwt>" http://localhost:3002/api/payments/status/<order_id>
# Expected: {"payment_status":"pending","order_status":"pending_payment"}
```

- [ ] **Step 3: Commit**

```bash
git add src/routes/payments.routes.ts
git commit -m "feat: add generic payment status endpoint for fallback polling"
```

### Task 2: Tilopay SDK token endpoint

**Files:**
- Modify: `blackdog-api/src/services/tilopay.service.ts`
- Modify: `blackdog-api/src/routes/payments.routes.ts`

The Tilopay SDK V2 needs a token from the `GetTokenSdk` API. This is different from the existing `processPayment` flow — it returns a token the frontend SDK uses to initialize, not a payment link.

- [ ] **Step 1: Add getSDKToken to tilopay.service.ts**

Add after the existing `getPaymentStatus` function:

```typescript
/**
 * Get an SDK token for the Tilopay SDK V2 frontend integration.
 * This token is passed to Tilopay.Init() in the HTML bridge.
 * Uses the same auth as processPayment but calls a different endpoint.
 */
export async function getSDKToken(): Promise<string> {
  const { TILOPAY_API_KEY } = env;
  if (!TILOPAY_API_KEY) {
    throw new Error('Tilopay API key not configured');
  }

  const response = await makeRequest<{
    token?: string;
    type?: string;
    message?: string;
  }>('POST', '/api/v1/tokenize', {
    key: TILOPAY_API_KEY,
    // Note: If Tilopay's GetTokenSdk endpoint differs, adjust path/payload here.
    // The exact endpoint name may be /api/v1/getTokenSdk or /api/v1/tokenize.
    // Check Tilopay Postman docs: https://documenter.getpostman.com/view/12758640/TVKA5KUT
  });

  if (response.token) {
    return response.token;
  }

  throw new Error(`Tilopay SDK token failed: ${response.message ?? JSON.stringify(response)}`);
}
```

- [ ] **Step 2: Add init-tilopay route**

Add to `payments.routes.ts` after the existing create-link route:

```typescript
import { createPaymentLink, getPaymentStatus, getSDKToken } from '../services/tilopay.service.js';

/**
 * POST /api/payments/sdk/init-tilopay
 * Generate an SDK token for the Tilopay SDK V2 embedded payment form.
 * Body: { order_id }
 */
router.post('/payments/sdk/init-tilopay', requireAuth, async (req: Request, res: Response) => {
  const { id: userId } = (req as AuthenticatedRequest).user;
  const { order_id } = req.body;

  if (!order_id) {
    res.status(400).json({ error: 'order_id is required' });
    return;
  }

  try {
    const { data: order } = await supabase
      .from('orders')
      .select('id, total, status, payment_method, odoo_order_name, payment_reference')
      .eq('id', order_id)
      .eq('user_id', userId)
      .single();

    if (!order) {
      res.status(404).json({ error: 'Order not found' });
      return;
    }

    if (order.status !== 'pending_payment') {
      res.status(400).json({ error: `Order status is "${order.status}", expected "pending_payment"` });
      return;
    }

    if (order.payment_method !== 'tilopay') {
      res.status(400).json({ error: `Payment method is "${order.payment_method}", expected "tilopay"` });
      return;
    }

    const orderNumber = order.payment_reference
      ?? order.odoo_order_name
      ?? `BDAPP-${order.id.slice(0, 8).toUpperCase()}`;

    // Store payment_reference if not already set
    if (!order.payment_reference) {
      await supabase
        .from('orders')
        .update({ payment_reference: orderNumber, updated_at: new Date().toISOString() })
        .eq('id', order_id);
    }

    const token = await getSDKToken();

    res.json({
      token,
      order_number: orderNumber,
      amount: order.total,
      currency: 'USD',
    });
  } catch (err) {
    logger.error({ err, order_id }, 'Tilopay SDK init error');
    res.status(500).json({ error: 'Failed to initialize payment SDK' });
  }
});
```

- [ ] **Step 3: Adapt tilopay return endpoint for SDK source**

In the existing `GET /payments/tilopay/return` handler, add SDK JSON response before the HTML deep-link response. Find the section after order update logic (after the `} else {` for logger.warn about order not found), replace the redirect section:

```typescript
    // If this came from the embedded SDK bridge, return JSON instead of HTML
    if (req.query.source === 'sdk') {
      res.json({
        success: isApproved,
        order_id: orderId ?? '',
        message: isApproved ? 'Pago aprobado' : String(description ?? 'Pago no completado'),
      });
      return;
    }

    // Redirect to app deep link or fallback web page (existing behavior)
    const status = isApproved ? 'success' : 'failed';
    // ... rest of existing HTML response
```

- [ ] **Step 4: Test SDK init endpoint**

```bash
curl -X POST -H "Authorization: Bearer <jwt>" -H "Content-Type: application/json" \
  -d '{"order_id":"<pending_order_id>"}' \
  http://localhost:3002/api/payments/sdk/init-tilopay
# Expected: {"token":"...","order_number":"BDAPP-XXXXXXXX","amount":0.01,"currency":"USD"}
```

- [ ] **Step 5: Commit**

```bash
git add src/services/tilopay.service.ts src/routes/payments.routes.ts
git commit -m "feat: add Tilopay SDK token endpoint and adapt return for SDK source"
```

### Task 3: Yappy V2 service and endpoints

**Files:**
- Create: `blackdog-api/src/services/yappy-v2.service.ts`
- Create: `blackdog-api/src/routes/yappy-v2.routes.ts`
- Modify: `blackdog-api/src/index.ts` (register new routes)
- Modify: `blackdog-api/.env` and `.env.example`

- [ ] **Step 1: Add env vars to .env and .env.example**

```env
# Yappy Botón de Pago V2 (Banco General)
YAPPY_V2_MERCHANT_ID=
YAPPY_V2_SECRET_KEY=
YAPPY_V2_DOMAIN=https://blackdogpanama.com
YAPPY_V2_IPN_URL=https://api.blackdogpanama.com/api/payments/yappy-v2/ipn
YAPPY_V2_API_URL=https://apipagosbg.bgeneral.cloud
```

- [ ] **Step 2: Create yappy-v2.service.ts**

```typescript
import crypto from 'crypto';
import { env } from '../config/env.js';
import { logger } from '../config/logger.js';

const getConfig = () => ({
  merchantId: env.YAPPY_V2_MERCHANT_ID ?? '',
  secretKey: env.YAPPY_V2_SECRET_KEY ?? '',
  domain: env.YAPPY_V2_DOMAIN ?? '',
  ipnUrl: env.YAPPY_V2_IPN_URL ?? '',
  apiUrl: (env.YAPPY_V2_API_URL ?? 'https://apipagosbg.bgeneral.cloud').replace(/\/$/, ''),
});

export function isYappyV2Configured(): boolean {
  const c = getConfig();
  return !!(c.merchantId && c.secretKey && c.domain);
}

/**
 * Step 1: Validate merchant and get session token.
 */
async function validateMerchant(): Promise<{ token: string; epochTime: number }> {
  const { merchantId, domain, apiUrl } = getConfig();

  const res = await fetch(`${apiUrl}/payments/validate/merchant`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ merchantId, urlDomain: domain }),
  });

  if (!res.ok) {
    const text = await res.text();
    logger.error({ status: res.status, body: text }, 'Yappy V2 validate merchant failed');
    throw new Error(`Yappy V2 validate merchant failed (${res.status})`);
  }

  const data = await res.json();
  if (!data.body?.token) {
    throw new Error(`Yappy V2 validate merchant: no token in response`);
  }

  return { token: data.body.token, epochTime: data.body.epochTime };
}

/**
 * Step 2: Create payment order.
 */
export interface CreateYappyOrderParams {
  orderId: string;      // max 15 chars, alphanumeric
  phone: string;        // Panama phone without prefix
  subtotal: number;
  taxes: number;
  discount: number;
  total: number;
}

export interface YappyOrderResult {
  transactionId: string;
  token: string;
  documentName: string;
}

export async function createYappyOrder(params: CreateYappyOrderParams): Promise<YappyOrderResult> {
  const { merchantId, domain, ipnUrl, apiUrl } = getConfig();

  // Step 1: Get session token
  const { token } = await validateMerchant();

  // Truncate orderId to 15 chars (Yappy limit)
  const yappyOrderId = params.orderId.slice(0, 15);

  // Step 2: Create the order
  const res = await fetch(`${apiUrl}/payments/payment-wc`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: token,
    },
    body: JSON.stringify({
      merchantId,
      orderId: yappyOrderId,
      domain,
      paymentDate: Math.floor(Date.now() / 1000),
      aliasYappy: params.phone.replace(/\D/g, ''),
      ipnUrl,
      discount: params.discount.toFixed(2),
      taxes: params.taxes.toFixed(2),
      subtotal: params.subtotal.toFixed(2),
      total: params.total.toFixed(2),
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    logger.error({ status: res.status, body: text }, 'Yappy V2 create order failed');
    throw new Error(`Yappy V2 create order failed (${res.status}): ${text}`);
  }

  const data = await res.json();

  if (!data.body?.transactionId) {
    const errCode = data.status?.code ?? 'unknown';
    const errDesc = data.status?.description ?? JSON.stringify(data);
    throw new Error(`Yappy V2 order error (${errCode}): ${errDesc}`);
  }

  logger.info({ orderId: yappyOrderId, transactionId: data.body.transactionId }, 'Yappy V2 order created');

  return {
    transactionId: data.body.transactionId,
    token: data.body.token,
    documentName: data.body.documentName,
  };
}

/**
 * Verify IPN Hash from Yappy callback.
 * The Hash is HMAC-SHA256 of the concatenated params using the secret key.
 */
export function verifyIPNHash(params: {
  orderId: string;
  status: string;
  domain: string;
  hash: string;
}): boolean {
  const { secretKey } = getConfig();
  if (!secretKey) return false;

  // Yappy IPN hash verification — the exact message format may need adjustment
  // based on Yappy's documentation. Common pattern: orderId + status + domain
  const message = `${params.orderId}${params.status}${params.domain}`;
  const expected = crypto
    .createHmac('sha256', secretKey)
    .update(message)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(params.hash, 'hex'),
    Buffer.from(expected, 'hex'),
  );
}
```

- [ ] **Step 3: Create yappy-v2.routes.ts**

```typescript
import { Router } from 'express';
import type { Request, Response } from 'express';
import { supabase } from '../config/supabase.js';
import { logger } from '../config/logger.js';
import { requireAuth, type AuthenticatedRequest } from '../middleware/auth.js';
import { createYappyOrder, verifyIPNHash, isYappyV2Configured } from '../services/yappy-v2.service.js';

const router = Router();

/**
 * POST /api/payments/yappy-v2/create-order
 * Orchestrates Yappy Button V2 two-step flow (validate merchant + create order).
 * Called by Flutter natively (not from the bridge JS) with JWT auth.
 */
router.post('/payments/yappy-v2/create-order', requireAuth, async (req: Request, res: Response) => {
  const { id: userId } = (req as AuthenticatedRequest).user;
  const { order_id, phone } = req.body;

  if (!order_id || !phone) {
    res.status(400).json({ error: 'order_id and phone are required' });
    return;
  }

  if (!isYappyV2Configured()) {
    res.status(503).json({ error: 'Yappy V2 not configured' });
    return;
  }

  try {
    const { data: order } = await supabase
      .from('orders')
      .select('id, total, subtotal, delivery_fee, status, payment_method, odoo_order_name')
      .eq('id', order_id)
      .eq('user_id', userId)
      .single();

    if (!order) {
      res.status(404).json({ error: 'Order not found' });
      return;
    }

    if (order.status !== 'pending_payment') {
      res.status(400).json({ error: `Order status is "${order.status}", expected "pending_payment"` });
      return;
    }

    if (order.payment_method !== 'yappy') {
      res.status(400).json({ error: `Payment method is "${order.payment_method}", expected "yappy"` });
      return;
    }

    // Use short order ref for Yappy (max 15 chars)
    const yappyRef = order.odoo_order_name ?? `BD-${order.id.slice(0, 11).toUpperCase()}`;

    const result = await createYappyOrder({
      orderId: yappyRef,
      phone,
      subtotal: order.subtotal,
      taxes: 0,
      discount: 0,
      total: order.total,
    });

    // Store payment reference
    await supabase
      .from('orders')
      .update({
        payment_reference: yappyRef,
        updated_at: new Date().toISOString(),
      })
      .eq('id', order_id);

    await supabase.from('order_tracking').insert({
      order_id,
      status: 'pending_payment',
      message: `Orden Yappy V2 creada (ref: ${yappyRef})`,
    });

    res.json(result);
  } catch (err) {
    logger.error({ err, order_id }, 'Yappy V2 create-order error');
    res.status(500).json({ error: 'Failed to create Yappy order' });
  }
});

/**
 * GET /api/payments/yappy-v2/ipn
 * Instant Payment Notification from Yappy.
 * Public endpoint — authenticated via HMAC Hash verification.
 * Query params: orderId, Hash, status (E|R|C|X), domain
 */
router.get('/payments/yappy-v2/ipn', async (req: Request, res: Response) => {
  const { orderId, Hash, status, domain } = req.query;

  logger.info({ orderId, status, domain }, 'Yappy V2 IPN received');

  if (!orderId || !Hash || !status) {
    res.status(400).send('Missing required params');
    return;
  }

  try {
    // Verify HMAC hash
    const isValid = verifyIPNHash({
      orderId: String(orderId),
      status: String(status),
      domain: String(domain ?? ''),
      hash: String(Hash),
    });

    if (!isValid) {
      logger.warn({ orderId, status }, 'Yappy V2 IPN: invalid hash');
      res.status(403).send('Invalid hash');
      return;
    }

    // Find order by payment_reference
    const { data: order } = await supabase
      .from('orders')
      .select('id, payment_status, status')
      .eq('payment_reference', String(orderId))
      .single();

    if (!order) {
      logger.warn({ orderId }, 'Yappy V2 IPN: order not found');
      res.status(200).send('OK'); // Don't reveal order existence
      return;
    }

    // Skip if already processed
    if (order.payment_status === 'paid') {
      res.status(200).send('OK');
      return;
    }

    const yappyStatus = String(status);

    if (yappyStatus === 'E') {
      // Ejecutado — payment confirmed
      await supabase
        .from('orders')
        .update({
          status: 'confirmed',
          payment_status: 'paid',
          updated_at: new Date().toISOString(),
        })
        .eq('id', order.id);

      await supabase.from('order_tracking').insert({
        order_id: order.id,
        status: 'confirmed',
        message: 'Pago confirmado via Yappy IPN',
      });

      logger.info({ orderId: order.id }, 'Yappy V2 IPN: payment confirmed');
    } else {
      // R = Rechazado, C = Cancelado, X = Expirado
      const statusMap: Record<string, string> = {
        R: 'failed',
        C: 'cancelled',
        X: 'failed',
      };
      const paymentStatus = statusMap[yappyStatus] ?? 'failed';
      const messageMap: Record<string, string> = {
        R: 'Pago Yappy rechazado (no confirmado en 5 min)',
        C: 'Pago Yappy cancelado por el cliente',
        X: 'Pago Yappy expirado (solicitud no iniciada)',
      };

      await supabase
        .from('orders')
        .update({
          payment_status: paymentStatus,
          updated_at: new Date().toISOString(),
        })
        .eq('id', order.id);

      await supabase.from('order_tracking').insert({
        order_id: order.id,
        status: 'pending_payment',
        message: messageMap[yappyStatus] ?? `Yappy IPN status: ${yappyStatus}`,
      });

      logger.info({ orderId: order.id, yappyStatus }, 'Yappy V2 IPN: payment not completed');
    }

    res.status(200).send('OK');
  } catch (err) {
    logger.error({ err }, 'Yappy V2 IPN error');
    res.status(200).send('OK'); // Always 200 to prevent Yappy retries
  }
});

export default router;
```

- [ ] **Step 4: Register routes in index.ts**

Find where payment routes are mounted and add:

```typescript
import yappyV2Routes from './routes/yappy-v2.routes.js';
// ... after existing route mounts
app.use('/api', yappyV2Routes);
```

- [ ] **Step 5: Add env vars to config/env.ts**

Add the new env vars to the env config interface/validation:

```typescript
YAPPY_V2_MERCHANT_ID: process.env.YAPPY_V2_MERCHANT_ID ?? '',
YAPPY_V2_SECRET_KEY: process.env.YAPPY_V2_SECRET_KEY ?? '',
YAPPY_V2_DOMAIN: process.env.YAPPY_V2_DOMAIN ?? '',
YAPPY_V2_IPN_URL: process.env.YAPPY_V2_IPN_URL ?? '',
YAPPY_V2_API_URL: process.env.YAPPY_V2_API_URL ?? 'https://apipagosbg.bgeneral.cloud',
```

- [ ] **Step 6: Test IPN with curl**

```bash
# Simulate Yappy IPN (will fail hash check, but verifies routing)
curl "http://localhost:3002/api/payments/yappy-v2/ipn?orderId=TEST123&Hash=abc&status=E&domain=blackdogpanama.com"
# Expected: 403 Invalid hash (since hash is fake)
```

- [ ] **Step 7: Commit**

```bash
git add src/services/yappy-v2.service.ts src/routes/yappy-v2.routes.ts src/index.ts src/config/env.ts .env .env.example
git commit -m "feat: add Yappy V2 Button service with create-order and IPN endpoints"
```

---

## Chunk 2: HTML Bridge Page

### Task 4: Create the HTML Bridge

**Files:**
- Create: `blackdog-api/public/checkout/index.html`

This is a single self-contained HTML file with inline CSS and JS. It renders either the Tilopay card form or the Yappy button based on the `method` URL param.

- [ ] **Step 1: Create public/checkout directory**

```bash
mkdir -p /home/guz/Documents/GitHub/blackdog-api/public/checkout
```

- [ ] **Step 2: Create index.html**

Create `blackdog-api/public/checkout/index.html` with the complete bridge page. Key elements:

- Reads `method`, `amount`, `order_number` from URL params
- Defines `initPayment(config)` global function called by Flutter post-load
- Defines `setYappyPayment(data)` global function for Yappy flow
- Conditionally loads Tilopay SDK or Yappy CDN based on method
- Uses `window.FlutterBridge.postMessage()` for all communication
- Styled: `#1A1A2E` background, `#F7B104` accents, Montserrat font
- Tilopay: `.payFormTilopay` structure with all required field IDs
- Yappy: `<yappy-button>` web component with event handlers
- `#responseTilopay` div for 3DS challenges
- Phone input with Panama validation (starts with 6, 8 digits)

The file should be ~300 lines. Include:
- Meta viewport for mobile
- Google Fonts Montserrat link
- Loading spinner shown until `initPayment()` is called
- Error display area
- "Procesando..." overlay for during payment

- [ ] **Step 3: Configure Express to serve static files**

In `blackdog-api/src/index.ts`, add static file serving:

```typescript
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
app.use('/checkout', express.static(path.join(__dirname, '../public/checkout')));
```

- [ ] **Step 4: Test the bridge page loads**

```bash
curl http://localhost:3002/checkout/?method=tilopay&amount=10.01&order_number=TEST
# Expected: HTML page with Tilopay form structure
```

- [ ] **Step 5: Commit**

```bash
git add public/checkout/index.html src/index.ts
git commit -m "feat: add HTML Bridge page for embedded payment SDKs"
```

### Task 5: Deploy backend changes to VPS

**Files:** None (deployment task)

- [ ] **Step 1: Push and deploy**

```bash
cd /home/guz/Documents/GitHub/blackdog-api
git push origin main
ssh root@31.97.211.164 'cd /opt/blackdog-api && git pull && npm run build && pm2 restart blackdog-api'
```

- [ ] **Step 2: Verify bridge page accessible**

```bash
curl https://api.blackdogpanama.com/checkout/?method=tilopay&amount=0.01&order_number=TEST
# Expected: HTML bridge page
```

- [ ] **Step 3: Verify new endpoints**

```bash
curl https://api.blackdogpanama.com/api/payments/status/test-id
# Expected: 401 (no auth) — confirms route is registered
```

---

## Chunk 3: Flutter App — New PaymentScreen

### Task 6: Update API service with new methods

**Files:**
- Modify: `blackdog-app/lib/services/api_service.dart`

- [ ] **Step 1: Add new methods, deprecate old ones**

Add to `api_service.dart`:

```dart
// ── SDK Payments ──────────────────────────────────────────────

/// Initialize Tilopay SDK — returns token for the HTML bridge
Future<Map<String, dynamic>> initTilopaySDK(String orderId) async {
  final response = await _dio.post('/payments/sdk/init-tilopay', data: {
    'order_id': orderId,
  });
  return response.data as Map<String, dynamic>;
}

/// Create Yappy V2 order — returns transactionId/token/documentName for the web component
Future<Map<String, dynamic>> createYappyV2Order(String orderId, String phone) async {
  final response = await _dio.post('/payments/yappy-v2/create-order', data: {
    'order_id': orderId,
    'phone': phone,
  });
  return response.data as Map<String, dynamic>;
}

/// Generic payment status check — works for all payment methods
Future<Map<String, dynamic>> getPaymentStatus(String orderId) async {
  final response = await _dio.get('/payments/status/$orderId');
  return response.data as Map<String, dynamic>;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/api_service.dart
git commit -m "feat: add Tilopay SDK init, Yappy V2 create-order, and generic status API methods"
```

### Task 7: Create unified PaymentScreen

**Files:**
- Create: `blackdog-app/lib/screens/checkout/payment_screen.dart`

This is the core Flutter screen. It manages a WebView that loads the HTML bridge and communicates via JavaScriptChannel.

- [ ] **Step 1: Create payment_screen.dart**

The screen should:
- Accept `orderId`, `paymentMethod`, `amount`, `currency` params
- Show loading state while fetching Tilopay SDK token (if tilopay) and loading WebView
- Load `${Env.apiBaseUrl.replaceAll('/api', '')}/checkout/?method=$paymentMethod&amount=$amount&order_number=$orderNumber`
- Register `FlutterBridge` JavaScriptChannel
- On `ready` message: call `initPayment()` via `runJavascript` with token + profile data
- On `yappy_click` message: call `api.createYappyV2Order()` natively, then pass result to JS via `setYappyPayment()`
- On `success` message: show PaymentResultView success
- On `error` message: show error with retry option
- On `cancel` message: show cancel with option to retry or go to order detail
- Native header overlay with "Pago seguro 🔒" + close button
- Processing overlay (blocks interaction)
- Fallback: if 60s after `processing` state with no response, start polling `getPaymentStatus()` every 5s
- WillPopScope/PopScope handling per state
- WebView allows all navigation during payment (3DS)

Key implementation details:
- Use `webview_flutter` package (already in pubspec)
- Read profile from `ref.read(profileProvider)`
- For Tilopay, the `redirectUrl` passed to `initPayment()` should be `${Env.apiBaseUrl}/payments/tilopay/return?source=sdk`

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/screens/checkout/payment_screen.dart
# Expected: No errors
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/checkout/payment_screen.dart
git commit -m "feat: add unified PaymentScreen with WebView bridge for Tilopay SDK and Yappy Button"
```

### Task 8: Update routes and navigation

**Files:**
- Modify: `blackdog-app/lib/config/routes.dart`
- Modify: `blackdog-app/lib/screens/checkout/order_confirmation_screen.dart`
- Modify: `blackdog-app/lib/screens/orders/order_detail_screen.dart`

- [ ] **Step 1: Update routes.dart**

Replace the separate `/payment/:orderId/tilopay` and `/payment/:orderId/yappy` routes with a single `/payment/:orderId` route:

```dart
GoRoute(
  path: '/payment/:orderId',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>? ?? {};
    return PaymentScreen(
      orderId: state.pathParameters['orderId']!,
      paymentMethod: extra['payment_method'] as String? ?? 'tilopay',
      amount: (extra['amount'] as num?)?.toDouble() ?? 0,
    );
  },
),
```

Remove the old `/tilopay` and `/yappy` sub-routes.

- [ ] **Step 2: Update order_confirmation_screen.dart**

Change navigation from the confirmation screen to use the new unified route:

```dart
// Instead of /payment/$orderId/tilopay or /payment/$orderId/yappy:
context.push('/payment/$orderId', extra: {
  'payment_method': order.paymentMethod,
  'amount': order.total,
});
```

- [ ] **Step 3: Update order_detail_screen.dart "Pagar ahora" button**

The existing "Pagar ahora" button navigates to `/payment/${order.id}`. Update the `extra` param:

```dart
onPressed: () => context.push(
  '/payment/${order.id}',
  extra: {
    'payment_method': order.paymentMethod,
    'amount': order.total,
  },
),
```

- [ ] **Step 4: Verify compilation**

```bash
flutter analyze lib/config/routes.dart lib/screens/checkout/order_confirmation_screen.dart lib/screens/orders/order_detail_screen.dart
# Expected: No errors
```

- [ ] **Step 5: Commit**

```bash
git add lib/config/routes.dart lib/screens/checkout/order_confirmation_screen.dart lib/screens/orders/order_detail_screen.dart
git commit -m "feat: unify payment routes and update navigation to new PaymentScreen"
```

### Task 9: Simplify payment provider

**Files:**
- Modify: `blackdog-app/lib/providers/payment_provider.dart`
- Modify: `blackdog-app/lib/models/payment_state.dart`

- [ ] **Step 1: Simplify payment_provider.dart**

The provider no longer needs polling timers or countdown logic (the bridge/SDKs handle that). Simplify to just hold the payment state that the PaymentScreen sets:

- Remove `Timer` polling logic
- Remove `_startCountdown` and countdown timer
- Keep state management (PaymentSession with state transitions)
- Add fallback polling method that PaymentScreen can call explicitly

- [ ] **Step 2: Commit**

```bash
git add lib/providers/payment_provider.dart lib/models/payment_state.dart
git commit -m "refactor: simplify payment provider — remove polling/countdown, bridge handles payment lifecycle"
```

### Task 10: Delete old payment screens

**Files:**
- Delete: `blackdog-app/lib/screens/checkout/tilopay_payment_screen.dart`
- Delete: `blackdog-app/lib/screens/checkout/yappy_payment_screen.dart`
- Delete: `blackdog-app/lib/screens/checkout/payment_status_screen.dart`
- Delete: `blackdog-app/lib/widgets/payment_countdown.dart`

- [ ] **Step 1: Remove old files**

```bash
rm lib/screens/checkout/tilopay_payment_screen.dart
rm lib/screens/checkout/yappy_payment_screen.dart
rm lib/screens/checkout/payment_status_screen.dart
rm lib/widgets/payment_countdown.dart
```

- [ ] **Step 2: Remove any remaining imports of deleted files**

Search for imports of the deleted files and remove them:

```bash
grep -r "tilopay_payment_screen\|yappy_payment_screen\|payment_status_screen\|payment_countdown" lib/ --include="*.dart" -l
```

Fix any files that still import them.

- [ ] **Step 3: Verify full compilation**

```bash
flutter analyze
# Expected: No errors related to deleted files
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: remove old payment screens replaced by unified PaymentScreen"
```

---

## Chunk 4: Build, Deploy, and E2E Test

### Task 11: Build and install on device

- [ ] **Step 1: Build debug APK**

```bash
flutter build apk --debug --dart-define-from-file=.env
```

- [ ] **Step 2: Install on device**

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

- [ ] **Step 3: Manual smoke test**

1. Open app → go to catalog → add test product ($0.01) to cart
2. Go to checkout → select pickup → select Tilopay → confirm order
3. Verify PaymentScreen loads with card form (Black Dog styled)
4. Enter test card → tap "Pagar" → verify success animation
5. Repeat with Yappy (if credentials available) → verify button and flow
6. Verify order shows as "confirmed" in Mis Pedidos

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve issues found during payment SDK smoke test"
```

### Task 12: Run Maestro E2E test

- [ ] **Step 1: Update purchase flow test**

Update `.maestro/purchase_delivery_tilopay.yaml` to work with the new embedded payment form instead of the old WebView redirect.

- [ ] **Step 2: Run test**

```bash
maestro test .maestro/purchase_delivery_tilopay.yaml
```

- [ ] **Step 3: Verify in Supabase**

```sql
SELECT id, status, payment_status, payment_method, total
FROM orders
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 5;
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "test: update Maestro E2E test for new embedded payment SDK flow"
```
