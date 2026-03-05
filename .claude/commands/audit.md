Haz una auditoría completa de la app Flutter BlackDog. Revisa TODOS los archivos en lib/ y reporta:

## 1. Errores de compilación
- Imports rotos o faltantes
- Type mismatches
- Syntax errors

## 2. Rendimiento
- Providers sin `.select()` que causan rebuilds innecesarios
- Widgets que hacen `ref.watch()` de providers completos cuando solo necesitan un campo
- Listas sin `ListView.builder` (no lazy)
- Imágenes sin `CachedNetworkImage`
- `setState` usado para estado que debería estar en Riverpod

## 3. Navegación
- Rutas en `routes.dart` que no coinciden con `context.go()`/`context.push()` en screens
- StatefulShellRoute branches correctamente configurados
- Pantallas que pierden estado al navegar

## 4. Providers
- Providers que nunca se invalidan (sin TTL)
- Providers duplicados o redundantes
- AsyncNotifiers sin manejo de error correcto
- Cart provider con optimistic updates funcionando

## 5. Código muerto
- Imports no usados
- Variables/funciones no referenciadas
- Providers definidos pero nunca watched/read

## 6. Buenas prácticas
- Verificar que no hay llamadas HTTP directas (todo debe ir por ApiService)
- No hay keys/URLs hardcodeadas
- Modelos tienen `fromJson()` correcto
- UI en español, código en inglés

Corre `flutter analyze` al final y reporta el resultado.

Para cada issue encontrado indica:
- **Severidad**: Critical / High / Medium / Low
- **Archivo:línea**
- **Fix sugerido**

Termina con una tabla resumen de estado por módulo (Home, Catálogo, Búsqueda, Carrito, Checkout, Pedidos, Sucursales, Perfil, Auth).
