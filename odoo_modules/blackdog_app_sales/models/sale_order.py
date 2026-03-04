from odoo import models, fields, api
from odoo.exceptions import UserError


class SaleOrder(models.Model):
    _inherit = 'sale.order'

    # ─── App-specific fields ────────────────────────────────────
    is_app_order = fields.Boolean(
        string='Pedido de App',
        compute='_compute_is_app_order',
        store=True,
        help='Indica si el pedido proviene de la app móvil BlackDog',
    )
    app_order_ref = fields.Char(
        string='Ref. App',
        help='ID del pedido en Supabase/App',
        copy=False,
        index=True,
    )
    app_fulfillment_state = fields.Selection(
        [
            ('pending', 'Pendiente'),
            ('awaiting_payment', 'Esperando Pago'),
            ('paid', 'Pagado'),
            ('confirmed', 'Confirmado por Sucursal'),
            ('preparing', 'En Preparación'),
            ('ready', 'Listo para Entrega/Pickup'),
            ('dispatched', 'Despachado'),
            ('delivered', 'Entregado'),
            ('cancelled', 'Cancelado'),
        ],
        string='Estado Fulfillment',
        default='pending',
        tracking=True,
        help='Estado de preparación del pedido en la sucursal',
    )
    app_delivery_method = fields.Selection(
        [
            ('pickup', 'Retiro en Sucursal'),
            ('delivery', 'Delivery'),
        ],
        string='Método de Entrega',
        help='Cómo el cliente recibirá su pedido',
    )
    app_delivery_notes = fields.Text(
        string='Notas de Entrega',
        help='Instrucciones especiales del cliente',
    )
    app_customer_phone = fields.Char(
        string='Teléfono Cliente',
        help='Teléfono del cliente para contacto de entrega',
    )
    app_payment_method = fields.Selection(
        [
            ('tilopay', 'Tilopay (Tarjeta)'),
            ('yappy', 'Yappy'),
            ('cash', 'Efectivo al Recibir'),
        ],
        string='Método de Pago App',
        help='Forma de pago seleccionada en la app',
    )

    # ─── Computed: Payment status from Tilopay/Yappy ────────────
    app_payment_status = fields.Selection(
        [
            ('none', 'Sin Pago'),
            ('pending', 'Pendiente'),
            ('paid', 'Pagado'),
            ('failed', 'Fallido'),
            ('expired', 'Expirado'),
            ('refunded', 'Reembolsado'),
        ],
        string='Estado Pago App',
        compute='_compute_app_payment_status',
        store=True,
        help='Estado del pago calculado desde Tilopay o Yappy',
    )
    app_payment_link = fields.Char(
        string='Link de Pago App',
        compute='_compute_app_payment_link',
        help='Link de pago activo (Tilopay o Yappy)',
    )

    # ─── Computed fields ────────────────────────────────────────
    @api.depends('source_id', 'source_id.name')
    def _compute_is_app_order(self):
        for order in self:
            order.is_app_order = (
                order.source_id
                and order.source_id.name == 'BlackDog App'
            )

    @api.depends(
        'app_payment_method',
        'tilopay_transaction_ids.state',
        'yappy_button_payment_link',
    )
    def _compute_app_payment_status(self):
        for order in self:
            if not order.is_app_order:
                order.app_payment_status = 'none'
                continue

            if order.app_payment_method == 'cash':
                # Cash on delivery - paid when delivered
                if order.app_fulfillment_state == 'delivered':
                    order.app_payment_status = 'paid'
                else:
                    order.app_payment_status = 'pending'
                continue

            if order.app_payment_method == 'tilopay':
                order.app_payment_status = order._get_tilopay_status()
            elif order.app_payment_method == 'yappy':
                order.app_payment_status = order._get_yappy_status()
            else:
                order.app_payment_status = 'none'

    def _compute_app_payment_link(self):
        for order in self:
            if order.app_payment_method == 'tilopay':
                order.app_payment_link = order.tilopay_payment_link or ''
            elif order.app_payment_method == 'yappy':
                order.app_payment_link = order.yappy_button_payment_link or ''
            else:
                order.app_payment_link = ''

    def _get_tilopay_status(self):
        """Map Tilopay transaction state to app payment status."""
        if not self.tilopay_transaction_ids:
            return 'none'
        # Get latest transaction
        latest = self.tilopay_transaction_ids.sorted('create_date', reverse=True)[:1]
        mapping = {
            'draft': 'pending',
            'pending': 'pending',
            'paid': 'paid',
            'refunded': 'refunded',
            'partially_refunded': 'paid',
            'failed': 'failed',
            'expired': 'expired',
            'cancelled': 'failed',
        }
        return mapping.get(latest.state, 'none')

    def _get_yappy_status(self):
        """Map Yappy transaction state to app payment status."""
        yappy_txns = self.env['yappy.button.transaction'].search(
            [('sale_order_id', '=', self.id)],
            order='create_date desc',
            limit=1,
        )
        if not yappy_txns:
            return 'none'
        mapping = {
            'draft': 'pending',
            'pending': 'pending',
            'paid': 'paid',
            'failed': 'failed',
            'expired': 'expired',
            'cancelled': 'failed',
        }
        return mapping.get(yappy_txns.state, 'none')

    # ─── Payment actions ────────────────────────────────────────
    def action_create_app_payment_link(self):
        """Create payment link via Tilopay or Yappy based on app_payment_method."""
        self.ensure_one()
        if not self.is_app_order:
            raise UserError('Esta acción solo aplica a pedidos de la app.')

        if self.app_payment_method == 'tilopay':
            return self._create_tilopay_link()
        elif self.app_payment_method == 'yappy':
            return self._create_yappy_link()
        elif self.app_payment_method == 'cash':
            raise UserError('Los pedidos contra entrega no requieren link de pago.')
        else:
            raise UserError('Seleccione un método de pago primero.')

    def _create_tilopay_link(self):
        """Open Tilopay payment link creation wizard."""
        return {
            'type': 'ir.actions.act_window',
            'name': 'Crear Link Tilopay',
            'res_model': 'tilopay.confirm.payment.link.wizard',
            'view_mode': 'form',
            'target': 'new',
            'context': {
                'default_sale_order_id': self.id,
            },
        }

    def _create_yappy_link(self):
        """Open Yappy payment link creation wizard."""
        return {
            'type': 'ir.actions.act_window',
            'name': 'Crear Link Yappy',
            'res_model': 'yappy.button.confirm.wizard',
            'view_mode': 'form',
            'target': 'new',
            'context': {
                'default_sale_order_id': self.id,
            },
        }

    def action_resend_payment_link(self):
        """Resend the active payment link to the customer via chatter."""
        self.ensure_one()
        link = self.app_payment_link
        if not link:
            raise UserError('No hay link de pago activo para este pedido.')

        method_label = dict(
            self._fields['app_payment_method'].selection
        ).get(self.app_payment_method, '')

        self.message_post(
            body=(
                f'Link de pago ({method_label}) reenviado al cliente:<br/>'
                f'<a href="{link}" target="_blank">{link}</a>'
            ),
            message_type='comment',
            subtype_xmlid='mail.mt_comment',
            partner_ids=self.partner_id.ids,
        )

    # ─── Fulfillment actions ────────────────────────────────────
    def action_confirm_branch(self):
        """Sucursal confirma que puede preparar el pedido."""
        self.ensure_one()
        if self.app_payment_method != 'cash' and self.app_payment_status != 'paid':
            raise UserError(
                'No se puede confirmar: el pago aún no ha sido recibido.'
            )
        self.app_fulfillment_state = 'confirmed'
        self._notify_app_status_change('confirmed')

    def action_start_preparing(self):
        """Sucursal inicia preparación del pedido."""
        self.ensure_one()
        self.app_fulfillment_state = 'preparing'
        self._notify_app_status_change('preparing')

    def action_mark_ready(self):
        """Pedido listo para entrega o pickup."""
        self.ensure_one()
        self.app_fulfillment_state = 'ready'
        self._notify_app_status_change('ready')

    def action_dispatch(self):
        """Pedido despachado (solo delivery)."""
        self.ensure_one()
        self.app_fulfillment_state = 'dispatched'
        self._notify_app_status_change('dispatched')

    def action_mark_delivered(self):
        """Pedido entregado al cliente."""
        self.ensure_one()
        self.app_fulfillment_state = 'delivered'
        self._notify_app_status_change('delivered')

    def action_cancel_app_order(self):
        """Cancelar pedido de la app. Ofrece reembolso si pagó con Tilopay."""
        self.ensure_one()
        self.app_fulfillment_state = 'cancelled'
        self._notify_app_status_change('cancelled')

    def _notify_app_status_change(self, new_state):
        """Notify status change in chatter and via API webhook.

        TODO: Implement webhook call to blackdog-api for push notifications.
        """
        state_labels = dict(self._fields['app_fulfillment_state'].selection)
        label = state_labels.get(new_state, new_state)
        self.message_post(
            body=f'Estado de fulfillment actualizado a: <strong>{label}</strong>',
            message_type='notification',
            subtype_xmlid='mail.mt_note',
        )
