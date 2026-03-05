Corre un análisis rápido de la app Flutter BlackDog.

## Ejecutar
```bash
flutter analyze --no-fatal-infos 2>&1
```

## Reportar
1. **Errores** (critical): listar cada uno con archivo:línea y fix sugerido
2. **Warnings** (important): listar cada uno
3. **Infos**: solo mencionar el conteo total, no listar cada uno

## Formato de respuesta

Si hay errores:
```
❌ X errores, Y warnings

ERRORES:
- archivo.dart:123 — descripción — fix: ...
- archivo.dart:456 — descripción — fix: ...

WARNINGS:
- archivo.dart:789 — descripción
```

Si todo está limpio:
```
✅ Sin errores ni warnings (X infos)
```

NO leer archivos ni hacer análisis adicional. Solo correr el comando y reportar el resultado de forma concisa.
