from odoo import models, fields


class BlackdogAppLog(models.Model):
    _name = 'blackdog.app.log'
    _description = 'Log de Sincronización App'
    _order = 'create_date desc'
    _rec_name = 'summary'

    log_type = fields.Selection(
        [
            ('sync', 'Sincronización'),
            ('order', 'Pedido'),
            ('payment', 'Pago'),
            ('webhook', 'Webhook'),
            ('error', 'Error'),
        ],
        string='Tipo', required=True, index=True,
    )
    level = fields.Selection(
        [
            ('info', 'Info'),
            ('warning', 'Advertencia'),
            ('error', 'Error'),
        ],
        string='Nivel', default='info', required=True,
    )
    summary = fields.Char(string='Resumen', required=True)
    detail = fields.Text(string='Detalle')
    ref_model = fields.Char(string='Modelo Referencia', index=True)
    ref_id = fields.Integer(string='ID Referencia')
    queue_id = fields.Many2one(
        'blackdog.app.order.queue', string='Cola',
        ondelete='set null', index=True,
    )
    queue_line_id = fields.Many2one(
        'blackdog.app.order.queue.line', string='Línea de Cola',
        ondelete='set null', index=True,
    )
    app_order_id = fields.Many2one(
        'blackdog.app.order', string='Pedido App',
        ondelete='set null', index=True,
    )
