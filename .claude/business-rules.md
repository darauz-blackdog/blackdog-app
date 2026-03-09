# Reglas de Negocio — BlackDog App

Documento para presentación. Ordenado de lo más simple a lo más complejo.

---

## 1. Sucursales

### Visibilidad
- Cada sucursal tiene un flag `is_active`. Si está **desactivado**, la sucursal **no aparece en ningún lado** de la app (ni checkout, ni mapa, ni selector).
- Las 3 sucursales de Miami (Cantabria, Los Pueblos, Parque Omar) están desactivadas.

### Capacidades por sucursal
Cada sucursal tiene dos flags independientes:
- **`is_pickup_enabled`** — ¿Se puede recoger en tienda?
- **`is_delivery_enabled`** — ¿Se puede hacer delivery desde ahí?

Ejemplo: Villa Zaita, Versalles, Costa Verde y Chiriquí tienen pickup habilitado pero **delivery desactivado** porque ASAP no cubre esas zonas.

---

## 2. Delivery

### Regla de cobertura
- Radio fijo de **2 km** desde la dirección del cliente hasta la sucursal más cercana.
- Si no hay ninguna sucursal con `is_delivery_enabled = true` a menos de 2 km → **delivery no disponible**, solo pickup.

### Quién hace el delivery
- **ASAP** coordina y cobra el delivery directamente al cliente.
- BlackDog **no cobra delivery fee** en el total de la orden.
- En la app dice: *"El envío lo coordina y cobra ASAP"*.

---

## 3. Selección de sucursal

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

---

## 4. Stock

### Cómo funciona
- El stock se sincroniza de **Odoo** a **Supabase** cada 5 minutos.
- Cada producto tiene stock **por sucursal** (tabla `stock_by_branch`).
- El stock se **valida en checkout** (paso 1: Método de entrega), no en el carrito.

### Stock parcial
Si la sucursal asignada para delivery no tiene todos los productos:
- Se muestra un **warning amarillo** con los nombres de los productos sin stock.
- **No se bloquea** la orden — el cliente decide si continúa.

### Lógica de verificación
```
Para cada producto del carrito:
  → Consultar qty_available en stock_by_branch para esa sucursal
  → Si qty_available >= cantidad pedida → "en stock"
  → Si no → agregar a lista de "productos sin stock"
```

---

## 5. Flujo completo de Checkout

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
```

---

## 6. Resumen de datos en Supabase

| Tabla | Propósito | Registros |
|-------|-----------|-----------|
| branches | Sucursales con flags de estado | 17 (14 activas) |
| stock_by_branch | Stock por producto por sucursal | ~14,000 |
| products | Catálogo desde Odoo | ~942 |
| app_categories | Categorías simplificadas para la app | 14 |
| home_banners | Banners dinámicos del carrusel | Configurable desde admin |
| home_sections | Secciones de home (marcas/categorías) | Configurable desde admin |

---

## 7. Admin Panel (en desarrollo)

El panel web (`blackdog-admin`) permitirá gestionar:
- **Sucursales**: activar/desactivar, habilitar delivery/pickup
- **Categorías**: nombre, icono, orden, visibilidad
- **Banners**: crear/editar banners del carrusel con imágenes o gradientes
- **Secciones del home**: qué marcas/categorías mostrar

Todos los cambios en el admin se reflejan automáticamente en la app sin necesidad de actualización.
