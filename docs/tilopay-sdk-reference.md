# Tilopay SDK V2 - Reference

## Overview
Client-side JS SDK for custom payment forms. Handles card data securely + supports Yappy and SINPE Movil.

## Integration Flow

### 1. Include SDK
```html
<script src="https://app.tilopay.com/sdk/v2/sdk_tpay.min.js"></script>
```

### 2. Required HTML Structure
Must have a parent div with class `payFormTilopay` containing:

```html
<div class="payFormTilopay">
  <!-- Payment method selector -->
  <select id="tlpy_payment_method"></select>

  <!-- Card payment fields -->
  <div id="tlpy_card_payment_div">
    <select id="tlpy_saved_cards"></select>
    <input type="text" id="tlpy_cc_number" />
    <input type="text" id="tlpy_cc_expiration_date" /> <!-- format: MM/YY -->
    <input type="text" id="tlpy_cvv" />
  </div>

  <!-- Yappy phone field (hidden by default) -->
  <div id="tlpy_phone_number_div" style="display:none">
    <input type="text" id="tlpy_phone_number" />
  </div>
</div>

<!-- 3DS container (required) -->
<div id="responseTilopay"></div>
```

### 3. SDK Functions

#### `await Tilopay.Init(options)` - Initialize payment
Returns: `{ methods: [], cards: [], error? }`

**Required parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `token` | string | Token from API `GetTokenSdk` endpoint |
| `currency` | string(3) | ISO 4217: `USD`, `CRC` |
| `language` | string(2) | ISO 639-1: `es`, `en` |
| `amount` | decimal(12,2) | Purchase amount |
| `billToEmail` | string | Customer email |
| `orderNumber` | string | **Unique** per merchant. e.g. `sdk-1001` |
| `billToFirstName` | string | Customer first name |
| `billToLastName` | string | Customer last name |
| `billToAddress` | string | Customer address |
| `capture` | integer | `1` = capture, `0` = authorize only |
| `redirect` | string | Callback URL for final response |
| `subscription` | integer | `1` = save card, `0` = don't save |

**Conditional parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `typeDni` | integer | ID type (required for SINPE Movil) |
| `dni` | string | Customer ID number (required for SINPE Movil) |
| `phoneYappy` | string | Required when paying with Yappy |

**Recommended parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `billToAddress2` | string | Address line 2 |
| `billToCity` | string | City |
| `billToState` | string | State |
| `billToZipPostCode` | string | Postal code |
| `billToCountry` | string(2) | ISO 3166-1: `PA`, `CR` |
| `billToTelephone` | string | Phone |

**Optional:**
| Param | Type | Description |
|-------|------|-------------|
| `hashVersion` | string | `"V2"` |
| `returnData` | string | Base64 encoded custom data returned in callback |

#### `await Tilopay.startPayment()` - Process payment
No parameters. Requires all form fields filled. Returns error message on failure.

#### `await Tilopay.getCardType()` - Get card brand
Returns: `VISA`, `MASTERCARD`, or `AMEX`

#### `await Tilopay.getSinpeMovil()` - Get SINPE Movil instructions
Returns: `{ message, code, amount, number }`

#### `await Tilopay.updateOptions(options)` - Update init params
Same params as Init (except token/currency/language/amount). Returns `"Success"` or error.

#### `await Tilopay.getCipherData()` - Get encrypted card data (for tokenization)

### 4. Payment Method Detection
When `tlpy_payment_method` changes:
- Yappy method has id containing `:18`
- Show `tlpy_phone_number_div` for Yappy, hide card fields
- Show `tlpy_card_payment_div` for card payments

### 5. Callback/Redirect
After payment, user is redirected to the `redirect` URL with payment result parameters.

### 6. Supported Cards
- VISA, MASTERCARD, AMEX

### 7. Complete Example
```javascript
document.addEventListener("DOMContentLoaded", async function() {
  var initialize = await Tilopay.Init({
    token: '<from-api>',
    currency: "USD",
    language: "es",
    amount: 1,
    billToFirstName: "Jose",
    billToLastName: "Lopez",
    billToAddress: "Panama City",
    billToEmail: "customer@example.com",
    orderNumber: "sdk-" + Date.now(),
    capture: 1,
    redirect: "https://mysite.com/payment/callback",
    subscription: 0,
    hashVersion: "V2"
  });

  // Load payment methods into select
  initialize.methods.forEach(method => {
    var opt = document.createElement("option");
    opt.value = method.id;
    opt.text = method.name;
    document.getElementById("tlpy_payment_method").appendChild(opt);
  });

  // Load saved cards
  initialize.cards.forEach(card => {
    var opt = document.createElement("option");
    opt.value = card.id;
    opt.text = card.name;
    document.getElementById("tlpy_saved_cards").appendChild(opt);
  });
});

async function processPayment() {
  var payment = await Tilopay.startPayment();
  console.log(payment);
}
```

### 8. API for Token
Tilopay API docs: https://documenter.getpostman.com/view/12758640/TVKA5KUT
- Endpoint: `GetTokenSdk` - generates the token needed for `Tilopay.Init()`
