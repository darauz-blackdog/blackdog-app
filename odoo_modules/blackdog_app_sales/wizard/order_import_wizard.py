import json
from odoo import models, fields, api, _
from odoo.exceptions import UserError


class OrderImportWizard(models.TransientModel):
    _name = 'blackdog.app.order.import.wizard'
    _description = 'Importar Pedido App (JSON)'

    json_data = fields.Text(
        string='JSON del Pedido',
        required=True,
        help='Pegue aquí el JSON del pedido de la app para importar manualmente.',
    )
    auto_process = fields.Boolean(
        string='Procesar Automáticamente',
        default=True,
        help='Procesar la cola inmediatamente después de importar',
    )

    def action_import(self):
        """Validate JSON and create queue + queue line."""
        self.ensure_one()
        try:
            data = json.loads(self.json_data)
        except json.JSONDecodeError as e:
            raise UserError(
                _('JSON inválido: %s') % str(e)
            )

        # Support single order or batch
        orders = data if isinstance(data, list) else [data]

        queue = self.env['blackdog.app.order.queue'].create({
            'note': f'Importación manual de {len(orders)} pedido(s)',
        })

        for order_data in orders:
            self.env['blackdog.app.order.queue.line'].create({
                'queue_id': queue.id,
                'raw_data': json.dumps(order_data),
                'app_ref': order_data.get('app_ref', ''),
            })

        if self.auto_process:
            queue.action_process()

        return {
            'type': 'ir.actions.act_window',
            'name': _('Cola Importada'),
            'res_model': 'blackdog.app.order.queue',
            'res_id': queue.id,
            'view_mode': 'form',
            'target': 'current',
        }
