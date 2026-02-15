# CLAUDE.md — BlackDog App (Flutter)

## Proyecto

BlackDog App es una **app de e-commerce** (iOS + Android) para la cadena de pet shops **Black Dog Panamá** (~20 sucursales). Los productos vienen de **Odoo 18 Enterprise** y se cachean en **Supabase**. El backend API (Express + TypeScript) corre en un VPS separado.

## Repositorios

| Repo | Descripción | Estado |
|------|-------------|--------|
| `darauz-blackdog/blackdog-app` | Flutter app (este repo) | Fase 1 completa |
| `darauz-blackdog/blackdog-api` | Express.js backend (puerto 3002) | Fase 1 completa |
| `darauz-blackdog/Obisdian-BlackdogAPP` | Documentación Obsidian | Actualizado |

## Stack

- **Flutter 3.41.1** (Dart 3.11)
- **State management**: Riverpod 2.6
- **Navigation**: GoRouter 14.8
- **HTTP**: Dio 5.9 con interceptor JWT automático
- **Auth**: supabase_flutter 2.12 (email + Google + Apple Sign-In)
- **UI**: google_fonts (Montserrat + Inter), Material 3
- **Brand**: Primary `#F7B104` (dorado), Secondary `#1A1A2E` (navy)

## Estructura del proyecto

```
lib/
├── config/
│   ├── env.dart          # URLs de Supabase y API (dart-define)
│   └── routes.dart       # GoRouter con redirect por auth state
├── models/
│   ├── product.dart      # Product, ProductDetail, StockByBranch
│   ├── category.dart     # Category (tree structure)
│   └── branch.dart       # Branch (sucursal)
├── providers/
│   ├── auth_provider.dart      # authStateProvider, authNotifier
│   ├── products_provider.dart  # productList, search, featured, categories
│   └── service_providers.dart  # ApiService singleton
├── services/
│   └── api_service.dart  # Dio client con JWT interceptor
├── screens/
│   ├── auth/             # splash, login, register
│   ├── home/             # home (featured + categories)
│   ├── catalog/          # catalog grid, product detail, search
│   ├── cart/             # placeholder (Phase 2)
│   ├── profile/          # profile with menu
│   └── common/           # main_shell (bottom nav)
├── theme/
│   └── app_theme.dart    # Colores, tipografía, estilos globales
├── widgets/
│   ├── product_card.dart # Card reutilizable para productos
│   └── category_chip.dart
└── main.dart             # Entry point + Supabase init
```

## Backend API (puerto 3002)

El backend ya tiene estos endpoints funcionando:

### Públicos (sin auth)
```
GET  /api/health                    # Status de Odoo + Supabase
GET  /api/products?category_id=&page=&limit=&sort=  # Productos paginados
GET  /api/products/search?q=        # Full-text search (español)
GET  /api/products/featured?limit=  # Productos con stock
GET  /api/products/:id              # Detalle + stock por sucursal
GET  /api/categories?flat=true      # Árbol o lista plana
GET  /api/branches                  # 17 sucursales
```

### Requieren auth (Bearer token)
```
POST /api/auth/register             # Email signup + Odoo partner
POST /api/auth/complete-profile     # Post social login
GET  /api/auth/profile              # Perfil + direcciones
PUT  /api/auth/profile              # Actualizar perfil (sync a Odoo)
```

### Datos en Supabase (sincronizados de Odoo cada 5 min)
- **942** productos (retail con precio > 0)
- **141** categorías (bajo "Vendibles")
- **17** sucursales
- **14,334** registros de stock por sucursal

## Supabase

- **URL**: `https://nhuixqohuoqjaijgthpf.supabase.co`
- **Auth**: Email + password, Google OAuth, Apple Sign-In
- **13 tablas**: products, categories, branches, stock_by_branch, customer_profiles, addresses, carts, cart_items, orders, order_items, order_tracking, push_tokens, notifications, sync_logs
- **RLS**: Productos/categorías/branches públicos, datos de usuario scoped por auth.uid()

## Configuración para desarrollo

```bash
# Instalar dependencias
flutter pub get

# Correr en emulador (API apunta a localhost:3002 por defecto)
flutter run

# Para dispositivo físico, cambiar API_BASE_URL:
flutter run --dart-define=API_BASE_URL=http://TU_IP_VPS:3002/api

# Para Android emulator → el host es 10.0.2.2 (ya configurado en env.dart)
```

## Que falta (Fase 2+)

### Fase 2 — Carrito + Checkout + Pagos
- Backend: endpoints de carrito, crear orden en Odoo, integración Tilopay/Yappy
- Flutter: pantalla carrito, checkout (delivery/pickup), selección pago, WebView pago, confirmación

### Fase 3 — Pedidos + Tracking + Push
- Backend: endpoints órdenes, tracking, Firebase push
- Flutter: "Mis Pedidos", timeline tracking, notificaciones push

### Fase 4 — Sucursales + Perfil completo
- Flutter: mapa de sucursales, gestión de direcciones, editar perfil

### Fase 5 — QA + Deploy a Stores

## Convenciones

- Screens son **orquestadores** (inyectan providers, bindean estado)
- Lógica de negocio va en **services** o **providers**
- Modelos tienen `fromJson()` factory, no usan code generation
- Imports relativos (no package imports dentro del proyecto)
- Todo en español en la UI, código en inglés
- NO agregar dependencias sin discutir primero

## Prohibiciones

- No usar `setState` para estado global (usar Riverpod)
- No hacer llamadas HTTP directas (usar ApiService)
- No hardcodear URLs ni keys (usar Env)
- No modificar la estructura de carpetas sin razón
- No commitear keys/secrets
