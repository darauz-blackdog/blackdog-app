from odoo import models, fields, api


class BlackdogAppOrderLine(models.Model):
    _name = 'blackdog.app.order.line'
    _description = 'Línea de Pedido App'
    _order = 'sequence, id'

    order_id = fields.Many2one(
        'blackdog.app.order', string='Pedido',
        required=True, ondelete='cascade', index=True,
    )
    sequence = fields.Integer(default=10)

    product_id = fields.Many2one(
        'product.product', string='Producto', required=True,
    )
    product_name = fields.Char(
        string='Descripción',
        help='Nombre del producto al momento de la compra',
    )
    product_sku = fields.Char(string='SKU')

    quantity = fields.Float(string='Cantidad', default=1.0, required=True)
    price_unit = fields.Float(string='Precio Unitario', required=True)

    tax_ids = fields.Many2many(
        'account.tax', string='Impuestos',
    )
    tax_amount = fields.Monetary(
        string='Monto Impuesto', compute='_compute_amounts', store=True,
    )
    subtotal = fields.Monetary(
        string='Subtotal', compute='_compute_amounts', store=True,
    )
    total = fields.Monetary(
        string='Total', compute='_compute_amounts', store=True,
    )

    currency_id = fields.Many2one(
        related='order_id.currency_id', store=True,
    )

    @api.depends('quantity', 'price_unit', 'tax_ids')
    def _compute_amounts(self):
        for line in self:
            subtotal = line.quantity * line.price_unit
            tax_amount = 0.0
            if line.tax_ids:
                taxes = line.tax_ids.compute_all(
                    line.price_unit,
                    currency=line.currency_id,
                    quantity=line.quantity,
                    product=line.product_id,
                    partner=line.order_id.partner_id,
                )
                tax_amount = taxes['total_included'] - taxes['total_excluded']
                subtotal = taxes['total_excluded']
            line.subtotal = subtotal
            line.tax_amount = tax_amount
            line.total = subtotal + tax_amount
