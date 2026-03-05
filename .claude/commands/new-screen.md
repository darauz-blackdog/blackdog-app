Genera una nueva pantalla para la app BlackDog siguiendo las convenciones del proyecto.

## Preguntar al usuario
1. **Nombre de la pantalla** (ej: "favorites", "notifications", "order_tracking")
2. **Carpeta destino** (ej: "screens/favorites/", "screens/notifications/")
3. **Tipo**: ConsumerWidget (sin estado local) o ConsumerStatefulWidget (con estado local como scroll, tabs, forms)
4. **Tiene AppBar?** Sí/No
5. **Necesita provider nuevo?** Sí/No — si sí, crearlo en `lib/providers/`

## Generar archivos

### Pantalla (`lib/screens/{carpeta}/{nombre}_screen.dart`)
- Import relativos (no package imports)
- Usar `ConsumerWidget` o `ConsumerStatefulWidget` según la respuesta
- AppBar con logo BlackDog si aplica: `Image.asset('assets/icons/Black_Dog_Logo_V.png')`
- Usar `AppColors` y `GoogleFonts` del theme
- Skeleton loader para estado de carga (usar `ShimmerWrap` de `widgets/skeleton_loaders.dart`)
- Error state con botón "Reintentar" que invalida el provider

### Provider (si se necesita) (`lib/providers/{nombre}_provider.dart`)
- FutureProvider para datos read-only
- AsyncNotifier para datos con mutaciones
- Incluir `_autoInvalidate(ref, Duration(minutes: 15))` para TTL
- Import de `service_providers.dart`

### Ruta (`lib/config/routes.dart`)
- Agregar GoRoute dentro del StatefulShellBranch correspondiente
- Usar `_fadeThrough` para rutas de tab, `_sharedAxisY` para detail/push
- Si es una pantalla de tab principal, crear nuevo StatefulShellBranch

## Convenciones
- UI en español, código en inglés
- No usar `setState` para estado global
- No hacer llamadas HTTP directas (usar ApiService)
- No agregar dependencias sin discutir
- Usar `.select()` en `ref.watch()` cuando solo se necesita un campo
- Verificar con `flutter analyze` al terminar
