import logging
from odoo import models, fields, api, _
from odoo.exceptions import UserError

_logger = logging.getLogger(__name__)


class BlackdogAppOrder(models.Model):
    _name = 'blackdog.app.order'
    _description = 'Pedido App Móvil BlackDog'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'create_date desc'
    _rec_name = 'name'

    name = fields.Char(
        string='Número', required=True, readonly=True,
        default='Nuevo', copy=False, index=True,
    )
    state = fields.Selection(
        [
            ('pending', 'Pendiente'),
            ('paid', 'Pagado'),
            ('confirmed', 'Confirmado'),
            ('preparing', 'En Preparación'),
            ('ready', 'Listo'),
            ('dispatched', 'Despachado'),
            ('delivered', 'Entregado'),
            ('cancelled', 'Cancelado'),
        ],
        string='Estado', default='pending', required=True,
        tracking=True, index=True,
    )

    # ─── Customer ────────────────────────────────────────────────
    partner_id = fields.Many2one(
        'res.partner', string='Cliente', required=True,
        tracking=True, index=True,
    )
    customer_phone = fields.Char(string='Teléfono')
    customer_email = fields.Char(string='Email')

    # ─── External refs ───────────────────────────────────────────
    app_ref = fields.Char(
        string='Ref. App (Supabase)',
        copy=False, index=True,
        help='UUID del pedido en Supabase',
    )
    queue_line_id = fields.Many2one(
        'blackdog.app.order.queue.line', string='Línea de Cola',
        readonly=True, copy=False, ondelete='set null',
    )

    # ─── Delivery ────────────────────────────────────────────────
    delivery_method = fields.Selection(
        [
            ('pickup', 'Retiro en Sucursal'),
            ('delivery', 'Delivery'),
        ],
        string='Método de Entrega', required=True, default='pickup',
        tracking=True,
    )
    delivery_address_id = fields.Many2one(
        'res.partner', string='Dirección de Entrega',
    )
    delivery_notes = fields.Text(string='Notas de Entrega')
    delivery_fee = fields.Monetary(string='Costo de Delivery')

    # ─── Warehouse / Branch ──────────────────────────────────────
    warehouse_id = fields.Many2one(
        'stock.warehouse', string='Sucursal', required=True,
        tracking=True, index=True,
    )

    # ─── Lines ───────────────────────────────────────────────────
    line_ids = fields.One2many(
        'blackdog.app.order.line', 'order_id', string='Líneas',
    )
    payment_ids = fields.One2many(
        'blackdog.app.payment', 'app_order_id', string='Pagos',
    )

    # ─── Totals ──────────────────────────────────────────────────
    currency_id = fields.Many2one(
        'res.currency', string='Moneda',
        default=lambda self: self.env.company.currency_id,
    )
    amount_subtotal = fields.Monetary(
        string='Subtotal', compute='_compute_amounts', store=True,
    )
    amount_tax = fields.Monetary(
        string='Impuestos', compute='_compute_amounts', store=True,
    )
    amount_delivery = fields.Monetary(
        string='Delivery', compute='_compute_amounts', store=True,
    )
    amount_total = fields.Monetary(
        string='Total', compute='_compute_amounts', store=True,
    )

    # ─── Payment summary ─────────────────────────────────────────
    payment_method = fields.Selection(
        [
            ('tilopay', 'Tilopay (Tarjeta)'),
            ('yappy', 'Yappy'),
            ('cash', 'Efectivo al Recibir'),
        ],
        string='Método de Pago', tracking=True,
    )
    payment_status = fields.Selection(
        [
            ('none', 'Sin Pago'),
            ('pending', 'Pendiente'),
            ('paid', 'Pagado'),
            ('failed', 'Fallido'),
            ('refunded', 'Reembolsado'),
        ],
        string='Estado Pago',
        compute='_compute_payment_status', store=True,
    )

    # ─── Sale Order link ─────────────────────────────────────────
    sale_order_id = fields.Many2one(
        'sale.order', string='Pedido de Venta',
        readonly=True, copy=False, index=True,
    )
    sale_order_state = fields.Selection(
        related='sale_order_id.state', string='Estado Venta',
    )

    # ─── UTM ─────────────────────────────────────────────────────
    source_id = fields.Many2one('utm.source', string='UTM Source')
    medium_id = fields.Many2one('utm.medium', string='UTM Medium')

    @api.depends('line_ids.subtotal', 'delivery_fee')
    def _compute_amounts(self):
        for order in self:
            subtotal = sum(order.line_ids.mapped('subtotal'))
            tax = sum(order.line_ids.mapped('tax_amount'))
            order.amount_subtotal = subtotal
            order.amount_tax = tax
            order.amount_delivery = order.delivery_fee or 0.0
            order.amount_total = subtotal + tax + (order.delivery_fee or 0.0)

    @api.depends('payment_ids.state')
    def _compute_payment_status(self):
        for order in self:
            payments = order.payment_ids
            if not payments:
                order.payment_status = 'none'
            elif any(p.state == 'paid' for p in payments):
                order.payment_status = 'paid'
            elif any(p.state == 'refunded' for p in payments):
                order.payment_status = 'refunded'
            elif any(p.state == 'failed' for p in payments):
                order.payment_status = 'failed'
            else:
                order.payment_status = 'pending'

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('name', 'Nuevo') == 'Nuevo':
                vals['name'] = self.env['ir.sequence'].next_by_code(
                    'blackdog.app.order'
                ) or 'Nuevo'
        return super().create(vals_list)

    # ─── Fulfillment actions ─────────────────────────────────────

    def action_mark_paid(self):
        self.ensure_one()
        self.write({'state': 'paid'})
        self._log_state_change('paid')

    def action_confirm(self):
        """Confirm order and create sale.order in Odoo."""
        self.ensure_one()
        if self.payment_method != 'cash' and self.payment_status != 'paid':
            raise UserError(
                _('No se puede confirmar: el pago aún no ha sido recibido.')
            )
        self._create_sale_order()
        self.write({'state': 'confirmed'})
        self._log_state_change('confirmed')

    def action_start_preparing(self):
        self.ensure_one()
        self.write({'state': 'preparing'})
        self._log_state_change('preparing')

    def action_mark_ready(self):
        self.ensure_one()
        self.write({'state': 'ready'})
        self._log_state_change('ready')

    def action_dispatch(self):
        self.ensure_one()
        if self.delivery_method != 'delivery':
            raise UserError(_('Solo pedidos delivery pueden ser despachados.'))
        self.write({'state': 'dispatched'})
        self._log_state_change('dispatched')

    def action_mark_delivered(self):
        self.ensure_one()
        self.write({'state': 'delivered'})
        self._log_state_change('delivered')

    def action_cancel(self):
        self.ensure_one()
        if self.state == 'delivered':
            raise UserError(_('No se puede cancelar un pedido entregado.'))
        self.write({'state': 'cancelled'})
        self._log_state_change('cancelled')

    def _log_state_change(self, new_state):
        state_labels = dict(self._fields['state'].selection)
        label = state_labels.get(new_state, new_state)
        self.message_post(
            body=_('Estado actualizado a: <strong>%s</strong>') % label,
            message_type='notification',
            subtype_xmlid='mail.mt_note',
        )

    # ─── Create sale.order ───────────────────────────────────────

    def _create_sale_order(self):
        """Create native sale.order from this app order."""
        self.ensure_one()
        if self.sale_order_id:
            raise UserError(
                _('Ya existe un pedido de venta: %s') % self.sale_order_id.name
            )

        config = self.env['blackdog.app.config']._get_config()

        so_vals = {
            'partner_id': self.partner_id.id,
            'warehouse_id': self.warehouse_id.id,
            'team_id': config.default_sales_team_id.id or False,
            'source_id': self.source_id.id or False,
            'medium_id': self.medium_id.id or False,
            'client_order_ref': self.name,
            'note': self.delivery_notes or '',
            'order_line': [],
        }

        for line in self.line_ids:
            so_vals['order_line'].append((0, 0, {
                'product_id': line.product_id.id,
                'product_uom_qty': line.quantity,
                'price_unit': line.price_unit,
                'tax_id': [(6, 0, line.tax_ids.ids)] if line.tax_ids else [],
            }))

        # Add delivery fee as a service line
        if self.delivery_fee and self.delivery_method == 'delivery':
            delivery_product = config.delivery_product_id
            if delivery_product:
                so_vals['order_line'].append((0, 0, {
                    'product_id': delivery_product.id,
                    'product_uom_qty': 1,
                    'price_unit': self.delivery_fee,
                }))

        sale_order = self.env['sale.order'].create(so_vals)
        sale_order.action_confirm()
        self.sale_order_id = sale_order.id

        self.message_post(
            body=_('Pedido de venta creado: <a href="/odoo/sales/%s">%s</a>') % (
                sale_order.id, sale_order.name,
            ),
            message_type='notification',
            subtype_xmlid='mail.mt_note',
        )

        _logger.info(
            'Sale order %s created from app order %s',
            sale_order.name, self.name,
        )

    # ─── Smart button ────────────────────────────────────────────

    def action_view_sale_order(self):
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': _('Pedido de Venta'),
            'res_model': 'sale.order',
            'res_id': self.sale_order_id.id,
            'view_mode': 'form',
            'target': 'current',
        }
