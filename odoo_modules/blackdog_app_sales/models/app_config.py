from odoo import models, fields, api
from odoo.exceptions import UserError


class BlackdogAppConfig(models.Model):
    _name = 'blackdog.app.config'
    _description = 'Configuración App Móvil BlackDog'
    _rec_name = 'company_id'

    company_id = fields.Many2one(
        'res.company', string='Compañía',
        required=True, default=lambda self: self.env.company,
        index=True,
    )
    active = fields.Boolean(default=True)

    # ─── Tilopay ─────────────────────────────────────────────────
    tilopay_api_user = fields.Char(string='Tilopay Usuario')
    tilopay_api_password = fields.Char(string='Tilopay Contraseña')
    tilopay_api_key = fields.Char(string='Tilopay API Key')
    tilopay_api_base_url = fields.Char(
        string='Tilopay URL Base',
        default='https://app.tilopay.com',
    )
    tilopay_success_url = fields.Char(
        string='Tilopay URL Éxito',
        default='blackdog://payment/success',
    )
    tilopay_fail_url = fields.Char(
        string='Tilopay URL Fallo',
        default='blackdog://payment/failed',
    )

    # ─── Yappy ───────────────────────────────────────────────────
    yappy_merchant_id = fields.Char(string='Yappy Merchant ID')
    yappy_secret_key = fields.Char(string='Yappy Secret Key')
    yappy_domain = fields.Char(
        string='Yappy Dominio',
        default='https://pagos.blackdogpanama.com',
    )
    yappy_success_url = fields.Char(
        string='Yappy URL Éxito',
        default='blackdog://payment/success',
    )

    # ─── Backend API ─────────────────────────────────────────────
    backend_api_url = fields.Char(
        string='URL Backend API',
        default='http://31.97.211.164:3002/api',
    )
    backend_api_secret = fields.Char(string='Secret Backend API')

    # ─── Defaults ────────────────────────────────────────────────
    default_warehouse_id = fields.Many2one(
        'stock.warehouse', string='Almacén por Defecto',
    )
    default_sales_team_id = fields.Many2one(
        'crm.team', string='Equipo de Ventas',
    )
    auto_process_queue = fields.Boolean(
        string='Auto-procesar Cola',
        default=True,
        help='Procesar automáticamente las líneas de cola al recibirlas',
    )
    auto_confirm_paid = fields.Boolean(
        string='Auto-confirmar Pagados',
        default=False,
        help='Crear sale.order automáticamente cuando el pago es confirmado',
    )
    delivery_product_id = fields.Many2one(
        'product.product', string='Producto Delivery',
        help='Producto tipo servicio para cargos de delivery',
    )

    _sql_constraints = [
        ('company_uniq', 'unique(company_id)',
         'Solo puede existir una configuración por compañía.'),
    ]

    @api.model
    def _get_config(self):
        """Get or create config singleton for current company."""
        config = self.search([
            ('company_id', '=', self.env.company.id),
        ], limit=1)
        if not config:
            config = self.create({
                'company_id': self.env.company.id,
            })
        return config
