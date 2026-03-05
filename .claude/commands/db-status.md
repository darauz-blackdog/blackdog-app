Muestra el estado actual de los datos en Supabase para la app BlackDog.

## Proyecto Supabase
ID: `nhuixqohuoqjaijgthpf`

## Ejecutar esta query
```sql
SELECT
  (SELECT count(*) FROM products) as productos,
  (SELECT count(*) FROM products WHERE total_stock > 0) as productos_con_stock,
  (SELECT count(*) FROM categories) as categorias,
  (SELECT count(*) FROM branches WHERE is_active = true) as sucursales_activas,
  (SELECT count(*) FROM branches WHERE is_active = false) as sucursales_inactivas,
  (SELECT count(*) FROM stock_by_branch) as registros_stock,
  (SELECT count(*) FROM customer_profiles) as clientes,
  (SELECT count(*) FROM orders) as pedidos,
  (SELECT count(*) FROM carts) as carritos,
  (SELECT count(*) FROM cart_items) as items_en_carritos,
  (SELECT max(synced_at) FROM products) as ultima_sync_productos,
  (SELECT max(synced_at) FROM branches) as ultima_sync_sucursales;
```

## Formato de respuesta

Mostrar una tabla clara:

| Dato | Cantidad |
|------|----------|
| Productos | X |
| Con stock | X |
| Categorías | X |
| Sucursales activas | X |
| Sucursales inactivas | X |
| Registros de stock | X |
| Clientes registrados | X |
| Pedidos | X |
| Carritos activos | X |
| Items en carritos | X |

**Última sincronización:**
- Productos: fecha/hora
- Sucursales: fecha/hora

Si algún número parece anormal (0 productos, 0 stock, sync hace más de 24h), marcarlo con advertencia.
