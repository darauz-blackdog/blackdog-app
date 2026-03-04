import logging
from odoo import models, fields, api, _

_logger = logging.getLogger(__name__)


class BlackdogAppOrderQueue(models.Model):
    _name = 'blackdog.app.order.queue'
    _description = 'Cola de Pedidos App'
    _order = 'create_date desc'
    _rec_name = 'name'

    name = fields.Char(
        string='Número', required=True, readonly=True,
        default='Nuevo', copy=False, index=True,
    )
    state = fields.Selection(
        [
            ('draft', 'Borrador'),
            ('partially_completed', 'Parcialmente Completado'),
            ('completed', 'Completado'),
            ('failed', 'Fallido'),
        ],
        string='Estado', default='draft', required=True, index=True,
    )
    line_ids = fields.One2many(
        'blackdog.app.order.queue.line', 'queue_id', string='Líneas',
    )
    total_lines = fields.Integer(
        string='Total Líneas', compute='_compute_counts', store=True,
    )
    completed_lines = fields.Integer(
        string='Completadas', compute='_compute_counts', store=True,
    )
    failed_lines = fields.Integer(
        string='Fallidas', compute='_compute_counts', store=True,
    )
    note = fields.Text(string='Notas')

    @api.depends('line_ids.state')
    def _compute_counts(self):
        for queue in self:
            lines = queue.line_ids
            queue.total_lines = len(lines)
            queue.completed_lines = len(lines.filtered(
                lambda l: l.state == 'completed'
            ))
            queue.failed_lines = len(lines.filtered(
                lambda l: l.state == 'failed'
            ))

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get('name', 'Nuevo') == 'Nuevo':
                vals['name'] = self.env['ir.sequence'].next_by_code(
                    'blackdog.app.order.queue'
                ) or 'Nuevo'
        return super().create(vals_list)

    def action_process(self):
        """Process all pending lines in this queue."""
        self.ensure_one()
        pending_lines = self.line_ids.filtered(
            lambda l: l.state == 'pending'
        )
        for line in pending_lines:
            line.action_process()
        self._update_queue_state()

    def _update_queue_state(self):
        """Update queue state based on line states."""
        for queue in self:
            lines = queue.line_ids
            if not lines:
                continue
            states = set(lines.mapped('state'))
            if states == {'completed'}:
                queue.state = 'completed'
            elif 'failed' in states and 'completed' in states:
                queue.state = 'partially_completed'
            elif states == {'failed'}:
                queue.state = 'failed'

    @api.model
    def _cron_process_queues(self):
        """Cron job: process all pending queue lines."""
        pending_queues = self.search([('state', '=', 'draft')])
        for queue in pending_queues:
            try:
                queue.action_process()
            except Exception as e:
                _logger.error(
                    'Error processing queue %s: %s', queue.name, str(e)
                )
                self.env['blackdog.app.log'].create({
                    'log_type': 'error',
                    'level': 'error',
                    'summary': f'Error procesando cola {queue.name}',
                    'detail': str(e),
                    'queue_id': queue.id,
                })
