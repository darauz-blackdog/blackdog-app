# Skill: Crear Nuevo Modulo en BlackDog App

Checklist y template para crear nuevos modulos/screens siguiendo los patrones establecidos.

---

## Paso 1: Estructura de Archivos

```
lib/
  screens/{modulo}/
    {modulo}_screen.dart        # Screen principal (orquestador)
    {subscreen}_screen.dart     # Sub-screens si aplica
  providers/
    {modulo}_provider.dart      # Providers del modulo (si no existe)
  models/
    {modulo}.dart               # Modelo con fromJson() factory
  widgets/
    {modulo}_card.dart          # Widgets reutilizables del modulo
```

## Paso 2: Modelo

```dart
class MiModelo {
  final int id;
  final String nombre;
  // ... campos

  const MiModelo({required this.id, required this.nombre});

  factory MiModelo.fromJson(Map<String, dynamic> json) => MiModelo(
    id: json['id'] as int,
    nombre: json['name'] as String,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MiModelo && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

## Paso 3: Provider

```dart
// En lib/providers/{modulo}_provider.dart
import '../services/api_service.dart';
import '../providers/service_providers.dart';

// Para datos que se usan en una sola pantalla
final miListProvider = FutureProvider.autoDispose<List<MiModelo>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getMiModelo();
});

// Para datos con parametros
final miDetailProvider = FutureProvider.autoDispose.family<MiModelo, int>((ref, id) async {
  final api = ref.read(apiServiceProvider);
  return api.getMiModelo(id);
});

// Para estado mutable
class MiNotifier extends AutoDisposeAsyncNotifier<List<MiModelo>> {
  @override
  Future<List<MiModelo>> build() async {
    final api = ref.read(apiServiceProvider);
    return api.getMiModelo();
  }

  Future<void> agregar(MiModelo item) async {
    // logica...
    state = AsyncData([...state.value ?? [], item]);
  }
}
```

## Paso 4: Screen (Orquestador)

```dart
import '../../utils/responsive.dart';
import '../../widgets/responsive_center.dart';

class MiScreen extends ConsumerStatefulWidget {
  const MiScreen({super.key});

  @override
  ConsumerState<MiScreen> createState() => _MiScreenState();
}

class _MiScreenState extends ConsumerState<MiScreen> {
  // Controllers aqui, dispose en dispose()

  @override
  void dispose() {
    // Siempre disponer controllers
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);        // NUNCA .of(context).size
    final padding = MediaQuery.paddingOf(context);   // NUNCA .of(context).padding
    final isWide = Responsive.isExpanded(context);   // NUNCA width >= 600

    final dataAsync = ref.watch(miListProvider);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxContentWidth: 700,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context),
          ),
          child: dataAsync.when(
            data: (items) => _buildContent(items, isWide),
            loading: () => const SkeletonLoader(...),  // NUNCA SizedBox()
            error: (e, _) => _buildError(e),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<MiModelo> items, bool isWide) {
    if (isWide) {
      return _buildTabletLayout(items);  // Multi-column, side panel, etc.
    }
    return _buildPhoneLayout(items);
  }
}
```

## Paso 5: Ruta

```dart
// En lib/config/routes.dart, dentro del ShellRoute
GoRoute(
  path: '/mi-modulo',
  pageBuilder: (context, state) => _fadeThrough(state, const MiScreen()),
),
```

## Checklist Pre-Commit

### Performance
- [ ] Providers en `lib/providers/`, no en screens
- [ ] `.autoDispose` en providers de una sola pantalla
- [ ] `.select()` cuando solo necesitas subset del estado
- [ ] `ValueKey` en widgets animados dentro de listas
- [ ] `const` en todo widget estatico
- [ ] Controllers disposed en `dispose()`
- [ ] No side effects en `build()` ni en provider `build()`

### UI
- [ ] `AppColors` / `theme.colorScheme` - cero `Color(0xFF...)`
- [ ] `Responsive.padding(context)` - cero padding hardcodeado
- [ ] `Responsive.isExpanded(context)` - cero breakpoints hardcodeados
- [ ] `ResponsiveCenter` con `maxContentWidth` en screens
- [ ] `MediaQuery.sizeOf` y `MediaQuery.paddingOf` - nunca `.of(context).size`
- [ ] `SafeArea` en contenido que toque bordes
- [ ] `maxLines` + `TextOverflow.ellipsis` en texto dinamico
- [ ] `BoxFit` en toda imagen
- [ ] Loading states con `SkeletonLoader`, no vacios
- [ ] Layout tablet (>=600dp) alternativo si aplica
- [ ] Touch targets minimo 48x48

### Seguridad
- [ ] Input validation antes de enviar al API
- [ ] `maxLength` en TextFields
- [ ] URLs de WebView validadas contra whitelist
- [ ] No print/debugPrint de tokens o PII
- [ ] HTTP calls via `ApiService`, no directos a Supabase

### Arquitectura
- [ ] Screen solo orquesta - logica en providers/services
- [ ] Modelo con `fromJson()`, `==`, `hashCode`
- [ ] Imports relativos
- [ ] UI en espanol, codigo en ingles
