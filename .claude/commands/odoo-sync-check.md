Compara los datos entre Odoo y Supabase para detectar desincronización.

## Proyecto Supabase
ID: `nhuixqohuoqjaijgthpf`

## Comparaciones a hacer

### 1. Productos
- **Odoo**: Usar `mcp__claude_ai_BLACK_DOG_MCP__get_products` con limit=5 para obtener un sample y el total
- **Supabase**: `SELECT count(*) as total, count(*) FILTER (WHERE total_stock > 0) as con_stock FROM products;`
- Reportar diferencia en conteo total

### 2. Sucursales
- **Odoo**: Usar `mcp__claude_ai_BLACK_DOG_MCP__get_warehouses` para obtener almacenes/sucursales
- **Supabase**: `SELECT count(*) FILTER (WHERE is_active), count(*) FILTER (WHERE NOT is_active) FROM branches;`
- Reportar diferencias

### 3. Categorías
- **Odoo**: Usar `mcp__claude_ai_BLACK_DOG_MCP__search_records` con model='product.public.category'
- **Supabase**: `SELECT count(*) FROM categories;`
- Reportar diferencia

### 4. Stock
- **Supabase**: `SELECT count(*), min(synced_at), max(synced_at) FROM stock_by_branch;`
- Si última sync > 10 minutos, marcar como WARNING

## Formato de respuesta

| Dato | Odoo | Supabase | Estado |
|------|------|----------|--------|
| Productos | X | Y | ✅/⚠️ |
| Sucursales | X | Y | ✅/⚠️ |
| Categorías | X | Y | ✅/⚠️ |

**Última sync de stock**: hace X minutos

### Discrepancias encontradas
Listar cualquier diferencia con detalle.

### Recomendaciones
Si hay desincronización, sugerir acciones (ej: "Ejecutar sync manual", "Verificar cron job").
