{
    'name': 'BlackDog App Sales',
    'version': '18.0.2.0.0',
    'category': 'Sales',
    'summary': 'Gestión de pedidos desde la app móvil BlackDog (modelos independientes)',
    'description': """
        Módulo para gestionar pedidos realizados desde la app móvil BlackDog.

        Arquitectura: Modelos independientes (patrón Shopify).
        - Cola de importación: recibe JSON desde Express API
        - Pedidos App: modelo propio con workflow de fulfillment (8 estados)
        - Pagos App: Tilopay, Yappy, Efectivo con tracking de estado
        - Sale Order: se crea al confirmar, con link reverso (smart button)
        - Webhooks: endpoints HTTP para crear pedidos y actualizar pagos
        - Dashboard: gráficas por semana, sucursal, estado, y método de pago
        - Wizard: importación manual de pedidos JSON (para testing)
    """,
    'author': 'BlackDog Panamá',
    'website': 'https://blackdogpanama.com',
    'license': 'LGPL-3',
    'depends': [
        'sale_management',
        'stock',
        'utm',
    ],
    'data': [
        # Security
        'security/security.xml',
        'security/ir.model.access.csv',
        'security/ir_rule.xml',
        # Data
        'data/ir_sequence_data.xml',
        'data/ir_cron_data.xml',
        'data/utm_data.xml',
        'data/crm_team_data.xml',
        'data/product_data.xml',
        # Views
        'views/app_config_views.xml',
        'views/app_order_views.xml',
        'views/app_order_queue_views.xml',
        'views/app_payment_views.xml',
        'views/app_log_views.xml',
        'views/dashboard_views.xml',
        'views/sale_order_views.xml',
        'views/res_config_settings_views.xml',
        'views/menu.xml',
        # Wizard
        'wizard/order_import_wizard_views.xml',
    ],
    'assets': {},
    'installable': True,
    'application': True,
    'auto_install': False,
}
