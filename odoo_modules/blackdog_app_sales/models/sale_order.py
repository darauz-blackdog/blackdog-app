from odoo import models, fields, _


class SaleOrder(models.Model):
    _inherit = 'sale.order'

    app_order_ids = fields.One2many(
        'blackdog.app.order', 'sale_order_id',
        string='Pedidos App',
    )
    app_order_count = fields.Integer(
        string='# Pedidos App',
        compute='_compute_app_order_count',
    )

    def _compute_app_order_count(self):
        for order in self:
            order.app_order_count = len(order.app_order_ids)

    def action_view_app_orders(self):
        """Smart button to view linked app orders."""
        self.ensure_one()
        if self.app_order_count == 1:
            return {
                'type': 'ir.actions.act_window',
                'name': _('Pedido App'),
                'res_model': 'blackdog.app.order',
                'res_id': self.app_order_ids[0].id,
                'view_mode': 'form',
                'target': 'current',
            }
        return {
            'type': 'ir.actions.act_window',
            'name': _('Pedidos App'),
            'res_model': 'blackdog.app.order',
            'view_mode': 'list,form',
            'domain': [('sale_order_id', '=', self.id)],
            'target': 'current',
        }
