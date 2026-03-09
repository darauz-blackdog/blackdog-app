# BlackDog App - Audit Report (2026-03-07)

Full codebase audit covering performance, security, UI/UX, and architecture.

---

## CORRECTO (Buenas Practicas Encontradas)

### Performance
1. **`MediaQuery.sizeOf(context)`** usado consistentemente en `branches_screen.dart`, `hero_banner_carousel.dart`, `main_shell.dart` - evita rebuilds innecesarios
2. **`CachedNetworkImage`** en `product_card.dart`, `product_detail_screen.dart`, `cart_screen.dart` - cache de imagenes correcto
3. **`ListView.builder` / `ListView.separated`** en todas las listas - lazy rendering correcto, no hay listas pre-construidas
4. **`ScrollController` disposed** en `CatalogScreen` (L49), `BranchesScreen` (L192-194)
5. **`TextEditingController` y `Timer` disposed** en `SearchScreen` (L28-32)
6. **`PageController` y `Timer` disposed** en `HeroBannerCarousel` (L68-71)
7. **`SliverChildBuilderDelegate`** para grids de catalogo y home - rendering lazy correcto
8. **Search debounce 400ms** con `Timer` en `SearchScreen` - evita llamadas API excesivas
9. **`ProductListParams` con `==` y `hashCode`** - cache keys correctos para `FutureProvider.family`
10. **`AnimationController` disposed** en `FadeInUp.dispose()` (L43)

### Seguridad
11. **No logging de tokens/PII** - cero `print()` o `debugPrint()` en todo `lib/`
12. **Token storage seguro** - JWTs via `supabase_flutter` (SecureStore iOS, EncryptedSharedPreferences Android)
13. **401 auto-signout** en `api_service.dart` (L25-29) - previene uso de tokens expirados
14. **Deep link seguro** para password recovery en `main.dart` (L37-41) via GoRouter
15. **Validacion de formularios** en login, register, change-password, Yappy phone input
16. **Google Client IDs sin default** - `Env.googleWebClientId/googleIosClientId` con `defaultValue: ''`
17. **Confirmacion de password** en register y change-password con largo minimo
18. **Delete account** requiere escribir "ELIMINAR" - proteccion UX contra accion destructiva
19. **`friendlyError()`** traduce errores a espanol sin exponer internals del API

### UI / Arquitectura
20. **Imports relativos** en todo el proyecto - no `package:blackdog_app/...`
21. **Riverpod para estado global** - cero `setState` para estado compartido
22. **GoRouter auth guard** con redirect correcto: loading->splash, unauth->login, auth+auth-route->home
23. **Transiciones custom** `_fadeThrough` y `_sharedAxisY` en `routes.dart` con curvas Material 3
24. **Responsive layout en MainShell** - `NavigationBar` (phone) vs `NavigationRail` (tablet) a 600dp
25. **`SafeArea` en bottom bars** - `checkout_screen.dart` (L1192), `cart_screen.dart` (L132)
26. **`maxLines` + `TextOverflow.ellipsis`** en todo texto dinamico
27. **`SkeletonLoader` custom** con shimmer via `AnimationController` propio
28. **`FadeInUp` con staggered delays** y `easeOutCubic` - animaciones suaves
29. **`AppColors` y `Theme.of(context).colorScheme`** usados en la mayoria del codebase
30. **Screens como orquestadores** - delegan logica a `CartNotifier`, `ApiService`, etc.
31. **`Responsive.padding(context)`** usado en `CatalogScreen`, `CheckoutScreen`, `CartScreen`, `LoginScreen`
32. **`ResponsiveCenter` con `maxContentWidth`** en `CartScreen`, `CheckoutScreen`, `LoginScreen`, `ProductDetailScreen`

---

## INCORRECTO (Problemas Encontrados)

### CRITICOS

#### SEC-1: Supabase anon key y VPS IP hardcodeados en source
- **Archivo:** `lib/config/env.dart:10,14`
- **Problema:** Key y IP como `defaultValue` se compilan en el binario
- **Fix:** Remover `defaultValue`, usar `.env` + `--dart-define-from-file` en CI

#### SEC-2: API corre sobre HTTP plano - tokens enviados sin encriptar
- **Archivo:** `lib/config/env.dart:14`, `lib/services/api_service.dart:21`
- **Problema:** `http://31.97.211.164:3002/api` - Bearer tokens en cleartext
- **Fix:** TLS en VPS (nginx + Let's Encrypt), cambiar a `https://`, agregar certificate pinning

#### SEC-3: WebView carga cualquier URL sin whitelist de dominio
- **Archivo:** `lib/screens/checkout/checkout_screen.dart:342`, `tilopay_payment_screen.dart:65`
- **Problema:** `paymentUrl` del API se carga sin validar dominio. CLAUDE.md exige whitelist
- **Fix:** Validar que URL sea `https://` y host termine en `tilopay.com` o `tilopay.cr`

#### PERF-1: Providers duplicados para branches - 3 providers llaman al mismo endpoint
- **Archivos:** `address_provider.dart:94`, `branches_screen.dart:15`, `checkout_screen.dart`
- **Problema:** Tres FutureProviders independientes llaman `api.getBranches()` sin cache compartido
- **Fix:** Un solo `FutureProvider<List<Branch>>` en `branch_provider.dart`

#### PERF-2: Cart items hacen fetch individual de productDetail por cada item
- **Archivo:** `lib/screens/cart/cart_screen.dart:216`
- **Problema:** 5 items = 5 requests `GET /api/products/:id`. productDetailProvider sin autoDispose
- **Fix:** Incluir stock en respuesta del cart API, o agregar `.autoDispose`

#### UI-1: Colores hardcodeados en multiples archivos
- **Archivos:** `catalog_screen.dart:133-136,334-336`, `hero_banner_carousel.dart:160`, `login_screen.dart:156-173`
- **Problema:** `Color(0xFF...)` literales que duplican constantes de `AppColors`
- **Fix:** Usar `AppColors.primary`, `AppColors.darkCard`, etc.

#### UI-2: State mutation en `build()` de CheckoutScreen
- **Archivo:** `lib/screens/checkout/checkout_screen.dart:116`
- **Problema:** `_initFromProviders()` muta estado dentro de `build()`
- **Fix:** Mover a `didChangeDependencies()` con guard `_initialized`

#### UI-3: Provider con logica de negocio dentro de archivo de screen
- **Archivo:** `lib/screens/branches/branches_screen.dart:15-18`
- **Problema:** `branchesProvider` declarado en screen file, retorna `List<dynamic>` sin tipado
- **Fix:** Consolidar en `lib/providers/branch_provider.dart` con tipo `List<Branch>`

### IMPORTANTES

#### SEC-4: Phone uniqueness check con race condition (TOCTOU)
- **Archivo:** `lib/providers/auth_provider.dart:129-138`
- **Problema:** Query directo a Supabase para verificar phone - race condition + phone enumeration
- **Fix:** Mover validacion al backend con unique constraint en transaccion

#### SEC-5: Payment success por URL substring matching - ambiguo
- **Archivo:** `checkout_screen.dart:356-375`, `tilopay_payment_screen.dart:79-95`
- **Problema:** `url.contains('status=approved')` matchea cualquier URL. Operator precedence sin parentesis
- **Fix:** Agregar parentesis, restringir check a dominio tilopay.com

#### SEC-6: Sin maxLength en campo de notas del checkout
- **Archivo:** `lib/screens/checkout/checkout_screen.dart:753`
- **Fix:** Agregar `maxLength: 500`

#### PERF-3: Scroll infinito puede disparar _loadMore multiples veces
- **Archivo:** `lib/screens/catalog/catalog_screen.dart:53-58`
- **Problema:** `_isLoadingMore = true` se setea despues del `setState`, no sincronamente
- **Fix:** Setear `_isLoadingMore = true` antes del `await`

#### PERF-4: FadeInUp en cada item del grid - re-anima en cada rebuild
- **Archivo:** `lib/screens/catalog/catalog_screen.dart:248-253`
- **Problema:** Sin `ValueKey`, items existentes re-ejecutan animacion en cada `setState`
- **Fix:** Agregar `key: ValueKey(product.id)` a cada `FadeInUp`

#### PERF-5: favoritesProvider causa rebuild de todo el grid al toggle
- **Archivo:** `lib/screens/catalog/catalog_screen.dart:254`
- **Problema:** `ref.watch(favoritesProvider).contains(product.id)` - cualquier toggle rebuilds todos los cards
- **Fix:** Usar `ref.watch(favoritesProvider.select((favs) => favs.contains(product.id)))`

#### PERF-6: Side effect en provider build() - SharedPreferences write
- **Archivo:** `lib/providers/branch_provider.dart:20`
- **Problema:** `SelectedBranchNotifier.build()` escribe a SharedPreferences como reaccion a nearestBranch
- **Fix:** Mover write a `selectAddress()` en `SelectedAddressNotifier`

#### UI-4: `MediaQuery.of(context).padding` en vez de `MediaQuery.paddingOf(context)`
- **Archivo:** `lib/screens/catalog/product_detail_screen.dart:190`
- **Fix:** Cambiar a `MediaQuery.paddingOf(context).bottom`

#### UI-5: Breakpoint hardcodeado en MainShell en vez de Responsive
- **Archivo:** `lib/screens/common/main_shell.dart:39`
- **Problema:** `width >= 600` en vez de `Responsive.isExpanded(context)`
- **Fix:** Usar `Responsive.isExpanded(context)`

#### UI-6: Scroll a branch seleccionada usa offset hardcodeado de 160px
- **Archivo:** `lib/screens/branches/branches_screen.dart:107`
- **Fix:** Usar `Scrollable.ensureVisible` con GlobalKey por card

#### UI-7: Bottom sheet colapsado sin SafeArea en branches
- **Archivo:** `lib/screens/branches/branches_screen.dart:385`
- **Fix:** Agregar `MediaQuery.paddingOf(context).bottom` al collapsed height

#### UI-8: Loading state del category carousel colapsa a 0px
- **Archivo:** `lib/screens/catalog/catalog_screen.dart:162-163`
- **Fix:** Usar `SkeletonLoader.card(height: 120)` en loading state
