# BlackDog App - Best Practices Rules

Rules derived from codebase audit (2026-03-07). Apply to ALL new code.

---

## 1. Providers (Riverpod)

- **UN solo provider por recurso** - nunca duplicar providers que llaman al mismo endpoint
- **Providers en `lib/providers/`** - nunca declarar providers en archivos de screen
- **Siempre tipar** - nunca `List<dynamic>`, usar modelos (`List<Branch>`, `List<Product>`)
- **`.autoDispose`** en providers que solo se usan en una pantalla
- **`.select()`** cuando solo necesitas un subset del estado:
  ```dart
  // MAL - rebuild en cualquier cambio de favoritos
  ref.watch(favoritesProvider).contains(id)
  // BIEN - rebuild solo cuando este ID cambia
  ref.watch(favoritesProvider.select((f) => f.contains(id)))
  ```
- **No side effects en `build()`** de Notifiers - mover writes a metodos explicitos
- **`ref.read()` para acciones**, `ref.watch()` para UI reactiva

## 2. Performance

- **`const` constructors** en todo widget que no dependa de parametros runtime
- **`ValueKey`** en widgets animados dentro de listas para evitar re-animacion:
  ```dart
  FadeInUp(key: ValueKey(product.id), ...)
  ```
- **Guards sincronos** en scroll listeners antes de async:
  ```dart
  if (_isLoading) return;
  _isLoading = true; // sync, antes del await
  ```
- **Limitar animaciones** - `FadeInUp` solo en los primeros N items visibles, no en scroll infinito
- **`MediaQuery.sizeOf(context)`** y **`MediaQuery.paddingOf(context)`** - nunca `.of(context).size` ni `.of(context).padding`

## 3. Seguridad

- **Nunca hardcodear keys/secrets** - usar `--dart-define-from-file` sin `defaultValue`
- **Solo HTTPS** para API calls en produccion
- **WebView whitelist** - validar dominio antes de cargar URL:
  ```dart
  final uri = Uri.tryParse(url);
  final allowed = uri != null && uri.scheme == 'https' &&
    (uri.host.endsWith('tilopay.com') || uri.host.endsWith('supabase.co'));
  ```
- **Validacion server-side** para uniqueness checks - no TOCTOU via client
- **`maxLength`** en todo TextField que va al API
- **Parentesis explicitos** en condiciones compuestas `&&`/`||`
- **No queries directos a Supabase** para validaciones - usar ApiService

## 4. UI / Layout

- **Nunca `height:` fijo** en contenedores con texto dinamico
- **`SizedBox(height:)` OK** para listas horizontales (es el patron correcto)
- **Loading states** nunca colapsen a `SizedBox()` - usar `SkeletonLoader` del mismo tamano
- **`AppColors`** o `Theme.of(context).colorScheme` - nunca `Color(0xFF...)`
- **Si Google Brand requiere color especifico**, documentar con comentario:
  ```dart
  // Google brand guideline - color mandatorio
  color: const Color(0xFF131314),
  ```
- **`Responsive.isExpanded(context)`** para breakpoints - nunca `width >= 600`
- **`Responsive.padding(context)`** para padding - nunca hardcodear
- **`ResponsiveCenter`** en screens que necesiten `maxContentWidth`
- **`SafeArea`** en todo contenido que toque bordes, incluyendo bottom sheets colapsados

## 5. Navigation / State

- **No mutar estado en `build()`** - usar `initState`, `didChangeDependencies`, o `addPostFrameCallback`
- **GoRouter para navegacion** - nunca `Navigator.push` directo
- **Auth guard** en `routes.dart` redirect - nunca en screens individuales

## 6. Widgets / Reusabilidad

- **Extraer widgets repetidos** (>2 usos) a `lib/widgets/`
- **Screens como orquestadores** - inyectan providers, bindean estado, no tienen logica
- **`maxLines` + `TextOverflow.ellipsis`** en todo texto dinamico
- **`BoxFit.contain` o `BoxFit.cover`** en toda imagen
- **Touch targets minimo 48x48**
- **`Scrollable.ensureVisible`** con `GlobalKey` para scroll programatico - nunca offsets hardcodeados
