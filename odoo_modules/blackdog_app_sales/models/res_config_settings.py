from odoo import models, fields, api


class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'

    # ─── Tilopay ─────────────────────────────────────────────────
    app_tilopay_api_user = fields.Char(
        string='Tilopay Usuario (App)',
        related='app_config_id.tilopay_api_user',
        readonly=False,
    )
    app_tilopay_api_password = fields.Char(
        string='Tilopay Contraseña (App)',
        related='app_config_id.tilopay_api_password',
        readonly=False,
    )
    app_tilopay_api_key = fields.Char(
        string='Tilopay API Key (App)',
        related='app_config_id.tilopay_api_key',
        readonly=False,
    )
    app_tilopay_api_base_url = fields.Char(
        string='Tilopay URL Base (App)',
        related='app_config_id.tilopay_api_base_url',
        readonly=False,
    )
    app_tilopay_success_url = fields.Char(
        string='Tilopay URL Éxito (App)',
        related='app_config_id.tilopay_success_url',
        readonly=False,
    )
    app_tilopay_fail_url = fields.Char(
        string='Tilopay URL Fallo (App)',
        related='app_config_id.tilopay_fail_url',
        readonly=False,
    )

    # ─── Yappy ───────────────────────────────────────────────────
    app_yappy_merchant_id = fields.Char(
        string='Yappy Merchant ID (App)',
        related='app_config_id.yappy_merchant_id',
        readonly=False,
    )
    app_yappy_secret_key = fields.Char(
        string='Yappy Secret Key (App)',
        related='app_config_id.yappy_secret_key',
        readonly=False,
    )
    app_yappy_domain = fields.Char(
        string='Yappy Dominio (App)',
        related='app_config_id.yappy_domain',
        readonly=False,
    )
    app_yappy_success_url = fields.Char(
        string='Yappy URL Éxito (App)',
        related='app_config_id.yappy_success_url',
        readonly=False,
    )

    # ─── Backend API ─────────────────────────────────────────────
    app_backend_api_url = fields.Char(
        string='URL Backend API',
        related='app_config_id.backend_api_url',
        readonly=False,
    )
    app_backend_api_secret = fields.Char(
        string='Secret Backend API',
        related='app_config_id.backend_api_secret',
        readonly=False,
    )

    # ─── Defaults ────────────────────────────────────────────────
    app_default_warehouse_id = fields.Many2one(
        'stock.warehouse', string='Almacén por Defecto (App)',
        related='app_config_id.default_warehouse_id',
        readonly=False,
    )
    app_default_sales_team_id = fields.Many2one(
        'crm.team', string='Equipo de Ventas (App)',
        related='app_config_id.default_sales_team_id',
        readonly=False,
    )
    app_auto_process_queue = fields.Boolean(
        string='Auto-procesar Cola',
        related='app_config_id.auto_process_queue',
        readonly=False,
    )
    app_auto_confirm_paid = fields.Boolean(
        string='Auto-confirmar Pagados',
        related='app_config_id.auto_confirm_paid',
        readonly=False,
    )
    app_delivery_product_id = fields.Many2one(
        'product.product', string='Producto Delivery',
        related='app_config_id.delivery_product_id',
        readonly=False,
    )

    # ─── Config singleton reference ──────────────────────────────
    app_config_id = fields.Many2one(
        'blackdog.app.config', string='Configuración App',
        compute='_compute_app_config_id',
    )

    @api.depends('company_id')
    def _compute_app_config_id(self):
        for record in self:
            record.app_config_id = self.env[
                'blackdog.app.config'
            ]._get_config()
