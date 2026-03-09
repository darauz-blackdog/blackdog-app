# Reglas de Negocio — BlackDog App

Documento para presentación. Ordenado de lo más simple a lo más complejo.

---

## 1. Catálogo y Productos

### Fuente de datos
- Los productos vienen de **Odoo 18 Enterprise** y se cachean en **Supabase**.
- Solo se sincronizan productos con `available_in_pos = true` y `list_price > 0`.
- Catálogo actual: ~3,800 productos publicados, ~2,900 con stock.

### Sincronización Odoo → Supabase

| Qué | Frecuencia | Método |
|-----|-----------|--------|
| Productos | Cada 5 min | Incremental (solo modificados) |
| Stock por sucursal | Cada 5 min | Reemplazo completo |
| Categorías | Cada hora | Upsert del árbol |
| Mapeo categoría + marca | Cada hora | Reglas sobre ruta de categoría Odoo |
| Sucursales | Diario 3am | 17 warehouses de Odoo |
| Imágenes (Shopify) | Diario 4am | Enriquece con fotos, descripciones, tags |

### Productos agotados
- Productos con `total_stock = 0` se muestran con badge **"Agotado"** y botón deshabilitado.
- El cliente puede ver el producto pero **no puede agregarlo al carrito**.
- Esto aplica en: catálogo, carruseles del home, y detalle de producto.

### Categorías
- 14 categorías simplificadas (`app_categories`) mapeadas de las ~141 categorías de Odoo.
- Cada categoría tiene: nombre, icono, orden, y flag `is_active`.
- Categorías inactivas no aparecen en la app.
- Editables desde el admin panel.

### Banners del Home
- Carrusel de banners dinámicos desde API (`GET /home/banners`).
- Cada banner puede ser: imagen full-bleed o gradiente con texto.
- Tap navega a: producto, categoría, marca, URL externa, o nada.
- Auto-rotación cada 5 segundos. Gestionables desde admin.

---

## 2. Sucursales

### Visibilidad
- Cada sucursal tiene un flag `is_active`. Si está **desactivado**, la sucursal **no aparece en ningún lado** de la app (ni checkout, ni mapa, ni selector).
- Las 3 sucursales de Miami (Cantabria, Los Pueblos, Parque Omar) están desactivadas.
- La API filtra sucursales inactivas antes de enviarlas.

### Capacidades por sucursal
Cada sucursal tiene dos flags independientes:
- **`is_pickup_enabled`** — ¿Se puede recoger en tienda?
- **`is_delivery_enabled`** — ¿Se puede hacer delivery desde ahí?

Ejemplo: Villa Zaita, Versalles, Costa Verde y Chiriquí tienen pickup habilitado pero **delivery desactivado** porque ASAP no cubre esas zonas.

---

## 3. Delivery

### Regla de cobertura
- Radio fijo de **2 km** desde la dirección del cliente hasta la sucursal más cercana.
- Si no hay ninguna sucursal con `is_delivery_enabled = true` a menos de 2 km → **delivery no disponible**, solo pickup.

### Quién hace el delivery
- **ASAP** coordina y cobra el delivery directamente al cliente.
- BlackDog **no cobra delivery fee** en el total de la orden.
- En la app dice: *"El envío lo coordina y cobra ASAP"*.

---

## 4. Selección de sucursal inteligente

### Para Delivery (automático)
El cliente **no elige** la sucursal. El sistema la asigna automáticamente usando esta prioridad:

1. Solo sucursales a **menos de 2 km** con delivery habilitado
2. De esas, la que tenga **stock completo** del carrito
3. Si varias tienen stock completo → la **más cercana**
4. Si ninguna tiene stock completo → la que tenga **más productos** disponibles

### Para Pickup (el cliente elige)
El cliente ve **todas las sucursales activas** con pickup habilitado, ordenadas por:

1. **Stock completo primero** (tiene todos los productos del carrito)
2. Luego por **cantidad de productos** disponibles (más es mejor)
3. Luego por **distancia** (más cerca es mejor)

Cada sucursal muestra:
- Nombre y dirección
- Distancia en km
- Badge: "Stock completo" (verde) o "3/5 items" (amarillo)

### Cambio de tipo de entrega
Al cambiar entre delivery y pickup, el sistema auto-selecciona la mejor sucursal para el nuevo tipo. Si la sucursal actual no soporta el nuevo tipo, se deselecciona.

---

## 5. Stock

### Pipeline de stock
```
Odoo (stock.quant por warehouse)
  ↓ variante → template mapping
  ↓ qty = quantity - reserved_quantity
  ↓ cada 5 minutos
Supabase (stock_by_branch)
  ↓ refresh_product_stock() → total_stock en products
  ↓
API → Flutter app
```

### Validación en checkout
- El stock se consulta por sucursal al entrar al paso de entrega (`POST /stock/check`).
- Para cada producto del carrito se verifica `qty_available >= cantidad pedida`.

### Stock parcial
Si la sucursal asignada para delivery no tiene todos los productos:
- Se muestra un **warning amarillo** con los nombres de los productos sin stock.
- **No se bloquea** la orden — el cliente decide si continúa.

### Validación contra Odoo (en desarrollo)
- Al confirmar orden, se validará stock **directo en Odoo** (no Supabase).
- Odoo es la fuente de verdad porque ahí convergen POS, Shopify y la app.
- Se creará un `sale.order` en Odoo con reserva de stock (`action_confirm`).
- Flujo por método de pago:
  - **Pago en tienda**: confirma orden en Odoo inmediatamente (reserva stock).
  - **Tilopay/Yappy**: orden queda en draft, se confirma al recibir pago.
- Si Odoo está caído: fallback a validación con Supabase, orden se marca para sync manual.

---

## 6. Favoritos

- Los favoritos se guardan en **Supabase** (tabla `favorites`) vinculados a la cuenta del usuario.
- Persisten entre dispositivos — mismo usuario, mismos favoritos.
- Si el usuario no está logueado, se guardan localmente en el dispositivo.
- Al loguearse, los favoritos locales se migran automáticamente a Supabase.
- Fallback: si falla la red, usa cache local.

---

## 7. Carrito

- El carrito se gestiona en el **backend** (tabla `carts` + `cart_items` en Supabase).
- Al tocar un producto en el carrito, navega al detalle del producto.
- Productos agotados no se pueden agregar al carrito.
- Cantidad máxima limitada por stock total disponible.

---

## 8. Flujo completo de Checkout

```
Paso 1: Método de entrega
├── ¿Hay sucursal con delivery a <2km?
│   ├── SÍ → Mostrar opción "Delivery via ASAP" (seleccionada por defecto)
│   │        Auto-asignar mejor sucursal por stock+distancia
│   │        Mostrar selector de dirección
│   │        Si stock parcial → warning con productos faltantes
│   │
│   └── NO → Opción delivery deshabilitada
│            "No hay sucursales con delivery en tu zona"
│
├── Opción "Recoger en tienda" (siempre disponible)
│   └── Mostrar lista de sucursales con stock+distancia
│       Cliente elige cuál
│
└── Botón "Continuar" (solo si sucursal seleccionada)

Paso 2: Método de pago
├── Tarjeta (Tilopay) — siempre disponible
├── Yappy — siempre disponible
└── Pago en tienda — solo si es pickup

Paso 3: Resumen
├── Productos + cantidades + precios
├── Sucursal asignada/elegida
├── Método de entrega y pago
├── Subtotal (sin delivery fee)
└── Botón "Confirmar pedido"

Post-confirmación (en desarrollo):
├── Validar stock en Odoo en tiempo real
├── Crear sale.order en Odoo
├── Pago en tienda → confirmar orden (reserva stock)
├── Tilopay/Yappy → confirmar después del pago
└── Si Odoo falla → orden en Supabase + flag para sync manual
```

---

## 9. Resumen de datos en Supabase

| Tabla | Propósito | Registros |
|-------|-----------|-----------|
| branches | Sucursales con flags de estado | 17 (14 activas) |
| stock_by_branch | Stock por producto por sucursal | ~14,000 |
| products | Catálogo desde Odoo (solo POS) | ~3,800 |
| app_categories | Categorías simplificadas para la app | 14 |
| home_banners | Banners dinámicos del carrusel | Configurable desde admin |
| home_sections | Secciones de home (marcas/categorías) | Configurable desde admin |
| favorites | Productos favoritos por usuario | Vinculado a auth.users |
| carts / cart_items | Carrito activo del usuario | Server-side |
| orders / order_items | Órdenes confirmadas | Con odoo_order_id |
| sync_logs | Log de sincronizaciones Odoo | Auto-limpieza >7 días |

---

## 10. Admin Panel (en desarrollo)

El panel web (`blackdog-admin`) permitirá gestionar:
- **Sucursales**: activar/desactivar, habilitar delivery/pickup por sucursal
- **Categorías**: nombre, icono, orden, visibilidad (`is_active`)
- **Banners**: crear/editar banners del carrusel con imágenes o gradientes, link a producto/categoría/marca/URL
- **Secciones del home**: qué marcas/categorías mostrar con productos
- **Productos**: publicar/despublicar (`is_published`)

Todos los cambios en el admin se reflejan automáticamente en la app sin necesidad de actualización.
