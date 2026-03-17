# Yappy Payment Button V2 - Reference

## Overview
Web component button from Banco General Panama. Two-step backend flow (validate merchant + create order) + frontend JS web component with event-driven UX.

## Environments

| Environment | API Base URL | CDN (Button JS) |
|------------|-------------|-----------------|
| **Production** | `https://apipagosbg.bgeneral.cloud` | `https://bt-cdn.yappy.cloud/v1/cdn/web-component-btn-yappy.js` |
| **Testing** | `https://api-comecom-uat.yappycloud.com` | `https://bt-cdn-uat.yappycloud.com/v1/cdn/web-component-btn-yappy.js` |

## Credentials
Generated from Yappy Comercial web portal:
1. Login as admin at comercial.yappy.com.pa
2. Go to "Metodos de cobro" > "Boton de Pago Yappy"
3. Select platform: "Desarrollo propio (PHP, Node.JS, .Net)"
4. Fill site URL and click "Activar"
5. Click "Generar clave secreta"
6. Get: **merchantId** + **Secret Key**

## Backend Integration (2 API Calls)

### Step 1: Validate Merchant
**POST** `{base_url}/payments/validate/merchant`

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "merchantId": "<from yappy comercial>",
  "urlDomain": "<registered domain URL>"
}
```

**Response:**
```json
{
  "status": { "code": "...", "description": "..." },
  "body": {
    "epochTime": 1234567890,
    "token": "<session_token>"
  }
}
```

### Step 2: Create Order
**POST** `{base_url}/payments/payment-wc`

**Headers:**
```
Authorization: <token from step 1>
Content-Type: application/json
```

**Body:**
```json
{
  "merchantId": "<from yappy comercial>",
  "orderId": "ABC123",         // string, alphanumeric, 1-15 chars, UNIQUE
  "domain": "<registered domain URL>",
  "paymentDate": 1234567890,   // epoch timestamp
  "aliasYappy": "6XXXXXXX",   // Panama phone number without prefix
  "ipnUrl": "https://mysite.com/api/yappy/ipn",
  "discount": "0.00",
  "taxes": "0.00",
  "subtotal": "10.00",
  "total": "10.01"             // min: "0.01"
}
```

**Response:**
```json
{
  "status": { "code": "...", "description": "..." },
  "body": {
    "transactionId": "...",
    "token": "...",
    "documentName": "..."
  }
}
```

## Frontend Integration

### Include Button
```html
<!-- Production -->
<script src="https://bt-cdn.yappy.cloud/v1/cdn/web-component-btn-yappy.js"></script>

<!-- Testing -->
<script src="https://bt-cdn-uat.yappycloud.com/v1/cdn/web-component-btn-yappy.js"></script>
```

### Button HTML
```html
<yappy-button theme="brand" rounded="true"></yappy-button>
```

### Button Themes
`brand`, `dark`, `light`, `white`, `clear-brand`, `clear-dark`

Optional: `rounded="true"` for rounded corners.

### JavaScript Events

| Event | Description |
|-------|-------------|
| `eventClick` | Fired when button is clicked. Use to call your backend to create order. |
| `eventSuccess` | Transaction completed successfully. |
| `eventError` | Transaction failed. |
| `isYappyOnline` | Returns `true`/`false` for Yappy availability. |

### Method to Send Payment Data

| Method | Description |
|--------|-------------|
| `eventPayment` | Receives object `{ transactionId, token, documentName }` from Step 2 response. |

### Property

| Property | Description |
|----------|-------------|
| `isButtonLoading` | Set `true` to show loading state, `false` to hide. |

### Integration Example
```javascript
const yappyButton = document.querySelector('yappy-button');

// When button clicked, call backend
yappyButton.addEventListener('eventClick', async () => {
  yappyButton.isButtonLoading = true;

  // Call YOUR backend endpoint that orchestrates Steps 1 & 2
  const response = await fetch('/api/yappy/create-order', {
    method: 'POST',
    body: JSON.stringify({ orderId: 'ORD-123', total: '10.00', phone: '6XXXXXXX' })
  });
  const data = await response.json();

  // Send payment data to Yappy button
  yappyButton.eventPayment = {
    transactionId: data.body.transactionId,
    token: data.body.token,
    documentName: data.body.documentName
  };
});

// Handle success
yappyButton.addEventListener('eventSuccess', () => {
  window.location.href = '/order-confirmation';
});

// Handle error
yappyButton.addEventListener('eventError', (e) => {
  console.error('Payment failed:', e.detail);
});

// Check Yappy availability
yappyButton.addEventListener('isYappyOnline', (e) => {
  if (!e.detail) {
    // Yappy is offline, show message to user
  }
});
```

## IPN (Instant Payment Notification)

Yappy sends a **GET** request to your `ipnUrl` with query params:

| Param | Description |
|-------|-------------|
| `orderId` | Your order ID |
| `Hash` | HMAC hash for verification (use your Secret Key) |
| `status` | `E` = Executed (paid), `R` = Rejected, `C` = Cancelled, `X` = Expired |
| `domain` | Your store domain |

### IPN Status Codes
- **E** (Ejecutado) - Customer confirmed payment, purchase complete
- **R** (Rechazado) - Customer didn't confirm within 5 minutes
- **C** (Cancelado) - Customer cancelled in Yappy/BG app
- **X** (Expirado) - Customer never initiated payment process

### Hash Verification
Use your **Secret Key** to verify the Hash parameter. This ensures the IPN came from Yappy.

## Error Codes

| Code | Description |
|------|-------------|
| E002 | Something went wrong. Try again. |
| E005 | Phone number not registered in Yappy. |
| E006 | Something went wrong. Try again. |
| E007 | Order already registered. |
| E008 | Something went wrong. Try again. |
| E009 | Order ID exceeds 15 digits. |
| E010 | Amount values incorrect. |
| E011 | URL field error. |
| E012 | Something went wrong. Try again. |
| E100 | Bad Request. |

## Testing
1. Register Gmail accounts for test program
2. Send to botondepagoyappy@bgeneral.com:
   - Merchant name
   - Gmail email for registration
   - Panama cell number
   - Android OS version
3. Wait for invitation to test app
4. Use UAT URLs for testing

## Support
Email: botondepagoyappy@bgeneral.com
