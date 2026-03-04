from odoo import models, fields


class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'

    # ─── Tilopay App Credentials ────────────────────────────────
    app_tilopay_api_user = fields.Char(
        string='Tilopay Usuario (App)',
        config_parameter='blackdog_app.tilopay_api_user',
        help='Usuario de API Tilopay exclusivo para la app móvil',
    )
    app_tilopay_api_password = fields.Char(
        string='Tilopay Contraseña (App)',
        config_parameter='blackdog_app.tilopay_api_password',
        help='Contraseña de API Tilopay exclusiva para la app móvil',
    )
    app_tilopay_api_key = fields.Char(
        string='Tilopay API Key (App)',
        config_parameter='blackdog_app.tilopay_api_key',
        help='API Key Tilopay exclusiva para la app móvil',
    )
    app_tilopay_api_base_url = fields.Char(
        string='Tilopay URL Base (App)',
        config_parameter='blackdog_app.tilopay_api_base_url',
        default='https://app.tilopay.com',
        help='URL base de la API de Tilopay',
    )
    app_tilopay_success_url = fields.Char(
        string='Tilopay URL Éxito (App)',
        config_parameter='blackdog_app.tilopay_success_url',
        default='blackdog://payment/success',
        help='Deep link de la app para redirección después de pago exitoso',
    )
    app_tilopay_fail_url = fields.Char(
        string='Tilopay URL Fallo (App)',
        config_parameter='blackdog_app.tilopay_fail_url',
        default='blackdog://payment/failed',
        help='Deep link de la app para redirección después de pago fallido',
    )

    # ─── Yappy App Credentials ──────────────────────────────────
    app_yappy_merchant_id = fields.Char(
        string='Yappy Merchant ID (App)',
        config_parameter='blackdog_app.yappy_merchant_id',
        help='Merchant ID de Yappy exclusivo para la app móvil',
    )
    app_yappy_secret_key = fields.Char(
        string='Yappy Secret Key (App)',
        config_parameter='blackdog_app.yappy_secret_key',
        help='Secret Key de Yappy exclusiva para la app móvil',
    )
    app_yappy_domain = fields.Char(
        string='Yappy Dominio (App)',
        config_parameter='blackdog_app.yappy_domain',
        default='https://pagos.blackdogpanama.com',
        help='Dominio para links de pago Yappy de la app',
    )
    app_yappy_success_url = fields.Char(
        string='Yappy URL Éxito (App)',
        config_parameter='blackdog_app.yappy_success_url',
        default='blackdog://payment/success',
        help='Deep link de la app para redirección después de pago Yappy exitoso',
    )

    # ─── App Backend API ────────────────────────────────────────
    app_backend_api_url = fields.Char(
        string='URL Backend API',
        config_parameter='blackdog_app.backend_api_url',
        default='http://31.97.211.164:3002/api',
        help='URL del backend Express.js para webhooks y notificaciones push',
    )
    app_backend_api_secret = fields.Char(
        string='Secret Backend API',
        config_parameter='blackdog_app.backend_api_secret',
        help='Token secreto para autenticar webhooks desde Odoo al backend',
    )
