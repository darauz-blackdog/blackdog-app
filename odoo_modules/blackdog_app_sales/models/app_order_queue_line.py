import json
import logging
from odoo import models, fields, api, _
from odoo.exceptions import UserError

_logger = logging.getLogger(__name__)


class BlackdogAppOrderQueueLine(models.Model):
    _name = 'blackdog.app.order.queue.line'
    _description = 'Línea de Cola de Pedidos'
    _order = 'create_date desc'

    queue_id = fields.Many2one(
        'blackdog.app.order.queue', string='Cola',
        required=True, ondelete='cascade', index=True,
    )
    state = fields.Selection(
        [
            ('pending', 'Pendiente'),
            ('completed', 'Completado'),
            ('failed', 'Fallido'),
        ],
        string='Estado', default='pending', required=True, index=True,
    )
    raw_data = fields.Text(
        string='JSON Crudo', required=True,
        help='Datos del pedido en formato JSON desde la API',
    )
    error_message = fields.Text(string='Mensaje de Error')
    app_order_id = fields.Many2one(
        'blackdog.app.order', string='Pedido App',
        readonly=True, copy=False, ondelete='set null',
    )
    app_ref = fields.Char(
        string='Ref. App', index=True,
        help='UUID del pedido en Supabase (extraído del JSON)',
    )

    def action_process(self):
        """Parse JSON and create blackdog.app.order."""
        for line in self:
            try:
                data = json.loads(line.raw_data)
                app_order = line._create_app_order(data)
                line.write({
                    'state': 'completed',
                    'app_order_id': app_order.id,
                    'error_message': False,
                })
                line.queue_id._update_queue_state()

                self.env['blackdog.app.log'].create({
                    'log_type': 'order',
                    'level': 'info',
                    'summary': f'Pedido {app_order.name} creado desde cola',
                    'queue_id': line.queue_id.id,
                    'queue_line_id': line.id,
                    'app_order_id': app_order.id,
                })
            except Exception as e:
                _logger.error(
                    'Error processing queue line %s: %s', line.id, str(e)
                )
                line.write({
                    'state': 'failed',
                    'error_message': str(e),
                })
                self.env['blackdog.app.log'].create({
                    'log_type': 'error',
                    'level': 'error',
                    'summary': f'Error procesando línea de cola #{line.id}',
                    'detail': str(e),
                    'queue_id': line.queue_id.id,
                    'queue_line_id': line.id,
                })

    def action_retry(self):
        """Reset to pending and reprocess."""
        for line in self:
            line.write({
                'state': 'pending',
                'error_message': False,
            })
        self.action_process()

    def _create_app_order(self, data):
        """Parse JSON data and create a blackdog.app.order record.

        Expected JSON structure:
        {
            "app_ref": "uuid-from-supabase",
            "partner_id": 123,  // or "partner_email": "..."
            "customer_phone": "+507-6000-0000",
            "customer_email": "foo@bar.com",
            "warehouse_id": 5,
            "delivery_method": "delivery",
            "delivery_fee": 3.50,
            "delivery_notes": "Tocar el timbre",
            "delivery_address": { ... },
            "payment_method": "tilopay",
            "lines": [
                {
                    "product_id": 42,
                    "product_name": "Dog Food 15lb",
                    "product_sku": "DF-15",
                    "quantity": 2,
                    "price_unit": 25.99,
                    "tax_ids": [1, 2]
                }
            ]
        }
        """
        # Resolve partner
        partner_id = data.get('partner_id')
        if not partner_id and data.get('partner_email'):
            partner = self.env['res.partner'].search([
                ('email', '=', data['partner_email']),
            ], limit=1)
            if partner:
                partner_id = partner.id
            else:
                raise UserError(
                    _('No se encontró cliente con email: %s')
                    % data['partner_email']
                )
        if not partner_id:
            raise UserError(_('Se requiere partner_id o partner_email'))

        # Resolve warehouse
        warehouse_id = data.get('warehouse_id')
        if not warehouse_id:
            config = self.env['blackdog.app.config']._get_config()
            warehouse_id = config.default_warehouse_id.id
        if not warehouse_id:
            raise UserError(_('Se requiere warehouse_id'))

        # Get UTM defaults
        source = self.env.ref(
            'blackdog_app_sales.utm_source_blackdog_app', raise_if_not_found=False
        )
        medium = self.env.ref(
            'blackdog_app_sales.utm_medium_mobile_app', raise_if_not_found=False
        )

        order_vals = {
            'app_ref': data.get('app_ref', ''),
            'partner_id': partner_id,
            'customer_phone': data.get('customer_phone', ''),
            'customer_email': data.get('customer_email', ''),
            'warehouse_id': warehouse_id,
            'delivery_method': data.get('delivery_method', 'pickup'),
            'delivery_fee': data.get('delivery_fee', 0.0),
            'delivery_notes': data.get('delivery_notes', ''),
            'payment_method': data.get('payment_method', 'cash'),
            'source_id': source.id if source else False,
            'medium_id': medium.id if medium else False,
            'queue_line_id': self.id,
            'line_ids': [],
        }

        # Parse lines
        for line_data in data.get('lines', []):
            product_id = line_data.get('product_id')
            if not product_id:
                raise UserError(
                    _('Línea sin product_id: %s') % json.dumps(line_data)
                )
            tax_ids = line_data.get('tax_ids', [])
            order_vals['line_ids'].append((0, 0, {
                'product_id': product_id,
                'product_name': line_data.get('product_name', ''),
                'product_sku': line_data.get('product_sku', ''),
                'quantity': line_data.get('quantity', 1),
                'price_unit': line_data.get('price_unit', 0.0),
                'tax_ids': [(6, 0, tax_ids)] if tax_ids else [],
            }))

        if not order_vals['line_ids']:
            raise UserError(_('El pedido no tiene líneas'))

        # Store app_ref on queue line for easy lookup
        self.app_ref = data.get('app_ref', '')

        return self.env['blackdog.app.order'].create(order_vals)
