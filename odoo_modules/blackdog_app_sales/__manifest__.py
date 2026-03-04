{
    'name': 'BlackDog App Sales',
    'version': '18.0.1.0.0',
    'category': 'Sales',
    'summary': 'Gestión de pedidos desde la app móvil BlackDog',
    'description': """
        Módulo para gestionar pedidos realizados desde la app móvil BlackDog.

        Funcionalidades:
        - Vista filtrada de pedidos de la app (list + kanban)
        - Integración con Tilopay y Yappy para pagos
        - Dashboard de métricas de ventas (graph + pivot)
        - Gestión de estados de fulfillment (7 estados)
        - Botones de acción: Crear/Reenviar link de pago
        - Notificaciones a sucursales via chatter
        - Credenciales separadas Tilopay/Yappy para la app
        - Panel de configuración en Ajustes
    """,
    'author': 'BlackDog Panamá',
    'website': 'https://blackdogpanama.com',
    'license': 'LGPL-3',
    'depends': [
        'sale_management',
        'stock',
        'utm',
        'tilopay_payment',
        'yappy_temp',
    ],
    'data': [
        'security/security.xml',
        'security/ir.model.access.csv',
        'data/utm_data.xml',
        'data/crm_team_data.xml',
        'views/sale_order_views.xml',
        'views/dashboard_views.xml',
        'views/res_config_settings_views.xml',
        'views/menu.xml',
    ],
    'assets': {},
    'installable': True,
    'application': True,
    'auto_install': False,
}
