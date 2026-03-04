from odoo import models, fields, api, _
from odoo.exceptions import UserError


class BlackdogAppPayment(models.Model):
    _name = 'blackdog.app.payment'
    _description = 'Pago App Móvil BlackDog'
    _order = 'create_date desc'
    _rec_name = 'name'

    name = fields.Char(
        string='Referencia', required=True, readonly=True,
        default='Nuevo', copy=False, index=True,
    )
    app_order_id = fields.Many2one(
        'blackdog.app.order', string='Pedido App',
        required=True, ondelete='cascade', index=True,
    )
    state = fields.Selection(
        [
            ('pending', 'Pendiente'),
            ('paid', 'Pagado'),
            ('failed', 'Fallido'),
            ('expired', 'Expirado'),
            ('refunded', 'Reembolsado'),
            ('cancelled', 'Cancelado'),
        ],
        string='Estado', default='pending', required=True, index=True,
    )
    payment_method = fields.Selection(
        [
            ('tilopay', 'Tilopay (Tarjeta)'),
            ('yappy', 'Yappy'),
            ('cash', 'Efectivo al Recibir'),
        ],
        string='Método de Pago', required=True,
    )
    currency_id = fields.Many2one(
        'res.currency', string='Moneda',
        default=lambda self: self.env.company.currency_id,
    )
    amount = fields.Monetary(string='Monto', required=True)

    # ─── External refs ───────────────────────────────────────────
    external_ref = fields.Char(
        string='Ref. Externa',
        help='ID de transacción en Tilopay/Yappy',
        index=True,
    )
    external_url = fields.Char(string='URL de Pago')

    # ─── Metadata ────────────────────────────────────────────────
    raw_response = fields.Text(
        string='Respuesta Gateway',
        help='Respuesta JSON completa del gateway de pago',
    )
    paid_date = fields.Datetime(string='Fecha de Pago')
    partner_id = fields.Many2one(
        related='app_order_id.partner_id', store=True,
        string='Cliente',
    )

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('name', 'Nuevo') == 'Nuevo':
                vals['name'] = self.env['ir.sequence'].next_by_code(
                    'blackdog.app.payment'
                ) or 'Nuevo'
        return super().create(vals_list)

    def action_mark_paid(self):
        self.ensure_one()
        self.write({
            'state': 'paid',
            'paid_date': fields.Datetime.now(),
        })
        # Check if order should transition to paid
        order = self.app_order_id
        if order.state == 'pending' and order.payment_status == 'paid':
            order.action_mark_paid()
            # Auto-confirm if configured
            config = self.env['blackdog.app.config']._get_config()
            if config.auto_confirm_paid:
                order.action_confirm()

    def action_mark_failed(self):
        self.ensure_one()
        self.write({'state': 'failed'})

    def action_refund(self):
        self.ensure_one()
        if self.state != 'paid':
            raise UserError(_('Solo se pueden reembolsar pagos completados.'))
        self.write({'state': 'refunded'})
