# Audit Pre-Play Store — BlackDog App + API

**Fecha**: 2026-05-06
**Alcance**: `blackdog-app` (Flutter) + `blackdog-api` (Express/TS)
**Foco**: Seguridad, rendimiento, funcionalidad — bloqueadores para lanzamiento en Google Play.

## Resumen ejecutivo

| Severidad | App | API | Total |
|-----------|-----|-----|-------|
| Critical  | 4   | 3   | 7     |
| High      | 4   | 4   | 8     |
| Medium    | 5   | 3   | 8     |
| Low       | 2   | 1   | 3     |

### Top 7 bloqueadores de lanzamiento

1. **API**: `/api/admin/status` sin auth, leak de URLs, versiones, UID Odoo (`src/routes/health.routes.ts:38`).
2. **App**: cero crash reporting + sin handler global de errores en Dart (`lib/main.dart:13-24`). Crashes en producción = invisibles.
3. **App**: WebView de pagos confía en mensaje `success` del bridge JS sin verificar contra API (`payment_screen.dart:211-214`). Vector de fraude.
4. **App**: Tokens Supabase en SharedPreferences (no Keystore). `flutter_secure_storage` está en `pubspec.yaml:37` pero nunca importado.
5. **API**: `app.use(cors())` wildcard sin `app.set('trust proxy', 1)` → rate limiter mal cuenta IPs detrás de nginx, un atacante bloquea a todos (`src/server.ts:24`, `src/middleware/rate-limit.ts:9`).
6. **API**: dos process managers corriendo (systemd + PM2) → restarts en carrera, 502s espontáneos.
7. **App**: AndroidManifest sin `allowBackup="false"` → tokens en SharedPrefs respaldables a Google.

---

## App — Seguridad

### Critical

- **Sin crash reporting ni global error handler** — `lib/main.dart:13-24`. No hay `runZonedGuarded`, `FlutterError.onError`, ni `PlatformDispatcher.instance.onError`. Crashes nativos y excepciones async no reportadas. Bloqueador de Play (Pre-launch report fallaría silenciosamente).
- **WebView de pagos confía en JS bridge** — `lib/screens/checkout/payment_screen.dart:211-214,256-260`. El handler `'success'` invalida cache y navega a confirmación sin re-consultar `getPaymentStatus(orderId)`. Un actor que inyecte JS (o manipule el HTML servido en `/checkout/`) puede marcar pagos falsos como exitosos. Solo el `_pollTimer` (línea 271) verifica contra API, y solo después de 60s.
- **JS injection en `setYappyError`** — `payment_screen.dart:241-242`. Interpolación de string en JS (`setYappyError('$msg')`) usando solo `replaceAll("'", " ").replaceAll('"', ' ')`. No protege contra `'` o saltos de línea. Reemplazar con `jsonEncode`.
- **Tokens en SharedPreferences** — `flutter_secure_storage` (`pubspec.yaml:37`) está declarado pero `grep -r "flutter_secure_storage" lib/` devuelve cero resultados. Supabase guarda access/refresh token en SharedPreferences sin cifrar.

### High

- **Sin certificate pinning** — `lib/services/api_service.dart:9-32`. Dio sin `HttpClientAdapter` con SSL pinning. El `CLAUDE.md:152` lo lista como requisito de prod pero no está implementado. MITM posible en redes hostiles.
- **WebView sin whitelist de dominio (bridge)** — `payment_screen.dart:103-119`. `_buildBridgeWebView` no implementa `onNavigationRequest`, así que la página puede navegar a cualquier URL. El bridge es propio (servido desde el VPS), pero si el HTML inyecta un iframe externo, queda fuera de control.
- **Deep link sin validar params** — `AndroidManifest.xml:34-40` declara handlers para `com.blackdogpanama.blackdog_app://login-callback` y `blackdogapp://payment-result`. Activity es `exported="true"`. Cualquier app puede dispararlos. `lib/config/routes.dart` debe validar query params antes de navegar.

### Medium

- **AndroidManifest sin `allowBackup="false"`** — `android/app/src/main/AndroidManifest.xml:6-10`. Default true en APIs <30. Tokens en SharedPrefs serían respaldados a Google Drive del usuario.
- **Sin `dataExtractionRules` ni `fullBackupContent`** — mismo archivo, mismas líneas.
- **`google_sign_in` con `serverClientId` con default vacío** — `lib/config/env.dart:10-13` (según hallazgo de exploración). Build release con misconfiguración no falla, solo rompe Google Sign-In silenciosamente.

### Low

- **`debugShowCheckedModeBanner: false`** — `main.dart:63`. Correcto para release.
- **`usesCleartextTraffic="false"`** — `AndroidManifest.xml:10`. Correcto.

---

## App — Rendimiento

### Medium

- **6 `ListView(...)` no-builder** en pantallas de catálogo/checkout/profile. Lista corta = OK; checkout puede crecer. Migrar a `ListView.builder` cuando los items lleguen de API.
- **`splash_screen.dart`** — 3 `AnimationController` en cold start. Verificar dispose correcto (los exploradores reportan que sí dispone).

### Low

- **Assets ~1.5MB total** — OK para Play (límite suave 100MB AAB).
- **`cached_network_image`** en uso. No se detectaron `Image.network` directos.
- **Sin leaks evidentes** — todos los `AnimationController`/`StreamSubscription` están en archivos que llaman `dispose`.

---

## App — Funcionalidad / Release-readiness

### Critical

- **Cero coverage real** — `test/widget_test.dart` es scaffold. `flutter test` solo corre el placeholder. Riesgo: regresiones invisibles. Mínimo: 1 widget test por screen crítico (login, checkout, payment).

### High

- **Apple Sign-In documentado pero no implementado** — `CLAUDE.md:21` lo lista, `lib/providers/auth_provider.dart` solo tiene email + Google. App Store lo exige si hay Google login. **No bloquea Play, sí App Store**.
- **`flutter.versionCode=1` en `local.properties:5`** — `pubspec.yaml:4` dice `1.0.0+1`. Flutter normalmente lee del pubspec, pero `local.properties` puede sobrescribir según orden. Documentar bump obligatorio.

### Medium

- **Maestro flows happy-path solamente** — `.maestro/purchase_flow.yaml`, `purchase_flow_tilopay.yaml`, `purchase_delivery_tilopay.yaml`, `performance_audit.yaml`. No cubren cancelación, fallo de pago, sin conexión, login fallido.
- **README.md** scaffold default (no afecta Play, sí GitHub).
- **Privacy policy URL** no referenciada en código ni assets. Play Console exige URL pública (Data Safety form).

### Low

- **Adaptive icon** configurado (`mipmap-anydpi-v26/ic_launcher.xml`).
- **21 screenshots** en `screenshots/` listos para store listing.

---

## API — Seguridad

### Critical

- **`/api/admin/status` sin auth** — `src/routes/health.routes.ts:38-107`. Devuelve `env.ODOO_URL`, `env.ODOO_DB`, `serverVersion`, `uid`, `env.SUPABASE_URL`, `env.TILOPAY_API_BASE_URL`. Cualquiera con la URL del API hace recon completo.
- **`app.use(cors())` wildcard** — `src/server.ts:24`. Con CORS permisivo + sin `trust proxy`, cualquier sitio puede llamar al API.
- **`app.set('trust proxy', 1)` ausente** — `src/server.ts`. `express-rate-limit` cuenta `127.0.0.1` (IP de nginx). Un usuario malicioso satura el límite y bloquea a todos los demás clientes mobile.

### High

- **Sin Zod en endpoints sensibles** — Zod 4 está en `package.json:29` pero no hay `src/schemas/`. Endpoints sin validación: `POST /orders`, `POST /cart/items`, `POST /payments/tilopay/create-link`, `POST /payments/yappy-v2/create-order`, `POST /auth/register`. Solo checks `if (!field)` ad-hoc.
- **Service-role JWT reusado como `x-api-key`** — `src/routes/orders.routes.ts:541` (según hallazgo de exploración). El JWT de service role es long-lived y rotarlo invalida sincronizaciones.
- **Sin `uncaughtException` / `unhandledRejection`** — `src/server.ts`. El proceso se reinicia (systemd + PM2), pero pierde la stack y no se loguea estructuradamente.
- **Rate limit global de 60/min** — `src/middleware/rate-limit.ts:9-13`. Catálogo + carrito + pagos comparten cuota. Un usuario activo agota fácil.

### Medium

- **PII en logs** — `src/routes/orders.routes.ts:90` y `src/routes/auth.routes.ts:51,53,121` (según exploración). `req.body` completo (notas con dirección, teléfono) y emails terminan en journald.
- **`.env.bak-2026-04-17`** — visible en `ls`. Verificar si está en `.gitignore` y trackeado en git.
- **Rate limit auth de 5/min** — `src/middleware/rate-limit.ts:3-7`. Razonable, pero se aplica por IP (con `trust proxy` mal config, todo cuenta como 127.0.0.1).

### Low

- **Helmet activo** en `/api` (`server.ts:33-49`) — buena base.
- **Error handler** no leakea stack en producción (`src/middleware/error-handler.ts:9`).

---

## API — Confiabilidad

### Critical

- **systemd + PM2 corriendo en paralelo** — `blackdog-api.service` (User=www-data, port 3002) y `pm2 list` muestran ambos. Al hacer deploy o restart, race condition → 502s.

### Medium

- **`/api/health` golpea Odoo+Supabase sin caché** — `health.routes.ts:8-32`. Llamada cada vez. Si la app hace polling, agota rate limit propio.
- **Odoo XML-RPC sin pool** — `src/config/odoo.ts:26`. Concurrencia serializa.
- **Sin handlers de errores no capturados** (también listado en Security/High).

---

## API — Rendimiento

### High

- **N+1 en `/home/sections`** — `src/routes/products.routes.ts:422` (según exploración). Loop de queries por sección.

### Medium

- **`select *`** en respuestas a mobile — `src/routes/cart.routes.ts:47`, `src/routes/orders.routes.ts:430`. Payload inflado en redes lentas.
- **Sin caché Redis** — catálogo cambia cada 5 min (sync), pero cada request golpea Supabase. TTL de 30-60s reduciría 10x.

---

## Endpoints que la app consume (mapa)

Públicos (sin auth):
- `GET /products`, `/products/:id`, `/products/search`, `/products/featured`
- `GET /categories`, `/app-categories`, `/brands`
- `GET /home/banners`, `/home/sections`
- `GET /branches`
- `POST /stock/check`
- `GET /health`

Con auth (Bearer Supabase JWT):
- `POST /auth/register`, `/auth/complete-profile`
- `GET /auth/profile`, `PUT /auth/profile`, `DELETE /auth/account`
- `GET /cart`, `POST /cart/items`, `PUT /cart/items/:id`, `DELETE /cart/items/:id`, `DELETE /cart`
- `POST /orders`, `GET /orders`, `GET /orders/:id`, `POST /orders/:id/cancel`
- `POST /payments/sdk/init-tilopay`, `/payments/sdk/init-yappy`
- `POST /payments/yappy-v2/create-order`, `POST /payments/yappy/create`
- `GET /payments/status/:id`, `GET /payments/tilopay/status/:id`
- `POST /payments/:id/retry`
- `GET /addresses`, `POST /addresses`, `PUT /addresses/:id`, `DELETE /addresses/:id`

---

## Plan de mitigación

Ver `/home/diego_bd/.claude/plans/mira-blackdog-app-y-blackdog-api-giggly-pnueli.md`. Fase 2 ataca los 7 bloqueadores.

---

## Notas de release (Play Store)

### versionCode / versionName
La fuente de verdad es `pubspec.yaml` línea 4: `version: <name>+<code>`. Flutter sobrescribe `local.properties` en cada `flutter pub get`, así que **siempre bumpar pubspec antes de cada upload**. Play Console rechaza versionCode duplicado.

### Variables de build necesarias para release
```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=API_BASE_URL=https://api.blackdogpanama.com/api \
  --dart-define=GOOGLE_WEB_CLIENT_ID=... \
  --dart-define=SENTRY_DSN=https://...@sentry.io/... \
  --dart-define=SENTRY_ENVIRONMENT=production \
  --dart-define=API_CERT_PINS=PIN_PRIMARIO,PIN_BACKUP
```

### Cómo obtener los SPKI pins
```bash
echo | openssl s_client -servername api.blackdogpanama.com \
  -connect api.blackdogpanama.com:443 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | base64
```
Generar al menos 2 pins (current + backup CA intermedia) antes de habilitar pinning en producción.

### Variables de entorno API (ya generadas)
- `ADMIN_API_KEY`: generada y agregada a `/opt/blackdog-api/.env` (2026-05-06).
- `CORS_ALLOWED_ORIGINS`: vacío (mobile no requiere; agregar dominios web admin si aplica).
