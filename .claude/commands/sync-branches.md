Sincroniza las sucursales de Black Dog entre People HR y Supabase.

## Pasos

1. **Leer sucursales de People HR** usando el MCP tool `mcp__claude_ai_BLACK_DOG_MCP__people_get_branches` para obtener la lista actual de sucursales activas con sus datos (nombre, dirección, is_active).

2. **Leer sucursales de Supabase** ejecutando:
   ```sql
   SELECT id, name, address, city, is_active, latitude, longitude FROM branches ORDER BY name;
   ```
   Proyecto Supabase: `nhuixqohuoqjaijgthpf`

3. **Comparar** ambas listas y reportar:
   - Sucursales en People HR que NO están en Supabase (nuevas)
   - Sucursales en Supabase que NO están en People HR (eliminar o desactivar)
   - Sucursales con nombre o dirección diferente (actualizar)
   - Sucursales marcadas como inactivas en People HR pero activas en Supabase

4. **Mostrar tabla de diferencias** al usuario antes de aplicar cambios.

5. **Preguntar al usuario** si quiere aplicar los cambios. Si confirma:
   - INSERT nuevas sucursales (con is_active=true, pedir coordenadas al usuario)
   - UPDATE nombres/direcciones que cambiaron
   - SET is_active=false para las que ya no existen
   - NO borrar registros, solo desactivar

6. **Verificar** el resultado final mostrando la tabla de sucursales actualizada.

## Notas
- Las coordenadas (latitude, longitude) deben verificarse con el usuario si hay sucursales nuevas
- La tabla en Supabase es `branches` con columnas: id, name, code, address, city, phone, email, latitude, longitude, opening_hours, is_pickup_enabled, is_delivery_enabled, is_active, synced_at
- IDs en Supabase son bigint (integer), en People HR son UUID — no intentar sincronizar IDs
