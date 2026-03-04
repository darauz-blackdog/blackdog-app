import json
import logging
import hmac
import hashlib
from odoo import http, _, SUPERUSER_ID
from odoo.http import request

_logger = logging.getLogger(__name__)


class BlackdogAppWebhook(http.Controller):

    def _verify_secret(self, data_bytes):
        """Verify the webhook secret from X-App-Secret header."""
        config = request.env['blackdog.app.config'].sudo()._get_config()
        secret = config.backend_api_secret
        if not secret:
            return True  # No secret configured, allow all

        received = request.httprequest.headers.get('X-App-Secret', '')
        expected = hmac.new(
            secret.encode(), data_bytes, hashlib.sha256
        ).hexdigest()
        return hmac.compare_digest(received, expected)

    def _json_response(self, data, status=200):
        return request.make_json_response(data, status=status)

    @http.route(
        '/blackdog/api/order/create',
        type='http', auth='none', methods=['POST'], csrf=False,
    )
    def create_order(self, **kwargs):
        """Receive order from Express API, create queue line, auto-process."""
        try:
            data_bytes = request.httprequest.get_data()
            if not self._verify_secret(data_bytes):
                return self._json_response(
                    {'error': 'Invalid secret'}, status=401
                )

            data = json.loads(data_bytes)
            env = request.env(user=SUPERUSER_ID)

            # Create or get queue
            queue = env['blackdog.app.order.queue'].create({})

            # Create queue line
            queue_line = env['blackdog.app.order.queue.line'].create({
                'queue_id': queue.id,
                'raw_data': json.dumps(data),
                'app_ref': data.get('app_ref', ''),
            })

            # Log
            env['blackdog.app.log'].create({
                'log_type': 'webhook',
                'level': 'info',
                'summary': f'Pedido recibido: {data.get("app_ref", "sin ref")}',
                'detail': json.dumps(data, indent=2),
                'queue_id': queue.id,
                'queue_line_id': queue_line.id,
            })

            # Auto-process if configured
            config = env['blackdog.app.config']._get_config()
            result = {
                'success': True,
                'queue_id': queue.id,
                'queue_line_id': queue_line.id,
            }

            if config.auto_process_queue:
                queue_line.action_process()
                if queue_line.app_order_id:
                    result['app_order_id'] = queue_line.app_order_id.id
                    result['app_order_name'] = queue_line.app_order_id.name

            return self._json_response(result)

        except json.JSONDecodeError:
            return self._json_response(
                {'error': 'Invalid JSON'}, status=400
            )
        except Exception as e:
            _logger.error('Webhook order create error: %s', str(e))
            return self._json_response(
                {'error': str(e)}, status=500
            )

    @http.route(
        '/blackdog/api/payment/webhook',
        type='http', auth='none', methods=['POST'], csrf=False,
    )
    def payment_webhook(self, **kwargs):
        """Receive payment status update from gateway or Express API.

        Expected JSON:
        {
            "app_ref": "uuid",           // OR "app_order_id": 123
            "payment_method": "tilopay",
            "status": "paid",            // paid, failed, expired, refunded
            "external_ref": "TXN-123",
            "amount": 45.99,
            "raw_response": { ... }
        }
        """
        try:
            data_bytes = request.httprequest.get_data()
            if not self._verify_secret(data_bytes):
                return self._json_response(
                    {'error': 'Invalid secret'}, status=401
                )

            data = json.loads(data_bytes)
            env = request.env(user=SUPERUSER_ID)

            # Find app order
            app_order = None
            if data.get('app_order_id'):
                app_order = env['blackdog.app.order'].browse(
                    data['app_order_id']
                ).exists()
            elif data.get('app_ref'):
                app_order = env['blackdog.app.order'].search([
                    ('app_ref', '=', data['app_ref']),
                ], limit=1)

            if not app_order:
                return self._json_response(
                    {'error': 'App order not found'}, status=404
                )

            status = data.get('status', 'pending')

            # Create or update payment
            existing_payment = env['blackdog.app.payment'].search([
                ('app_order_id', '=', app_order.id),
                ('external_ref', '=', data.get('external_ref', '')),
            ], limit=1)

            if existing_payment:
                existing_payment.write({
                    'state': status,
                    'raw_response': json.dumps(
                        data.get('raw_response', {}), indent=2
                    ),
                })
                payment = existing_payment
            else:
                payment = env['blackdog.app.payment'].create({
                    'app_order_id': app_order.id,
                    'payment_method': data.get(
                        'payment_method', app_order.payment_method
                    ),
                    'amount': data.get('amount', app_order.amount_total),
                    'state': status,
                    'external_ref': data.get('external_ref', ''),
                    'external_url': data.get('external_url', ''),
                    'raw_response': json.dumps(
                        data.get('raw_response', {}), indent=2
                    ),
                })

            # If paid, trigger fulfillment
            if status == 'paid':
                payment.action_mark_paid()

            # Log
            env['blackdog.app.log'].create({
                'log_type': 'payment',
                'level': 'info',
                'summary': (
                    f'Pago {status}: {payment.name} '
                    f'para {app_order.name}'
                ),
                'detail': json.dumps(data, indent=2),
                'app_order_id': app_order.id,
            })

            return self._json_response({
                'success': True,
                'payment_id': payment.id,
                'payment_name': payment.name,
                'order_state': app_order.state,
            })

        except json.JSONDecodeError:
            return self._json_response(
                {'error': 'Invalid JSON'}, status=400
            )
        except Exception as e:
            _logger.error('Payment webhook error: %s', str(e))
            return self._json_response(
                {'error': str(e)}, status=500
            )
