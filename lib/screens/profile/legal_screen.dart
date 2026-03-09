import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

enum LegalType { privacy, terms }

class LegalScreen extends StatelessWidget {
  final LegalType type;

  const LegalScreen({super.key, required this.type});

  String get _title =>
      type == LegalType.privacy ? 'Política de Privacidad' : 'Términos y Condiciones';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.padding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: type == LegalType.privacy
              ? _privacyContent(context)
              : _termsContent(context),
        ),
      ),
      ),
    );
  }

  List<Widget> _privacyContent(BuildContext context) {
    return [
      _lastUpdated(context),
      const SizedBox(height: 20),
      _sectionTitle(context, '1. Información que recopilamos'),
      _paragraph(context,
          'Black Dog Panamá recopila la siguiente información cuando usas nuestra aplicación:'),
      _bulletList(context, [
        'Nombre completo y correo electrónico',
        'Número de teléfono (opcional)',
        'Direcciones de envío',
        'Historial de pedidos y preferencias de compra',
        'Ubicación del dispositivo (solo cuando lo permites, para mostrar sucursales cercanas)',
        'Información del dispositivo para mejorar el rendimiento de la app',
      ]),
      const SizedBox(height: 16),
      _sectionTitle(context, '2. Uso de la información'),
      _paragraph(context,
          'Utilizamos tu información para:'),
      _bulletList(context, [
        'Procesar y entregar tus pedidos',
        'Comunicarnos contigo sobre el estado de tus compras',
        'Personalizar tu experiencia en la app',
        'Mejorar nuestros productos y servicios',
        'Cumplir con obligaciones legales',
      ]),
      const SizedBox(height: 16),
      _sectionTitle(context, '3. Compartir información'),
      _paragraph(context,
          'No vendemos ni compartimos tu información personal con terceros, excepto:'),
      _bulletList(context, [
        'Proveedores de pago (Tilopay) para procesar transacciones',
        'Servicios de entrega para completar tus pedidos',
        'Cuando sea requerido por ley o autoridades competentes',
      ]),
      const SizedBox(height: 16),
      _sectionTitle(context, '4. Seguridad de datos'),
      _paragraph(context,
          'Protegemos tu información mediante cifrado en tránsito (HTTPS/TLS) y almacenamiento seguro. '
          'Tus contraseñas se almacenan de forma encriptada y nunca son accesibles para nuestro equipo.'),
      const SizedBox(height: 16),
      _sectionTitle(context, '5. Tus derechos'),
      _paragraph(context, 'Tienes derecho a:'),
      _bulletList(context, [
        'Acceder a tus datos personales desde tu perfil',
        'Modificar tu información en cualquier momento',
        'Solicitar la eliminación completa de tu cuenta y datos',
        'Retirar tu consentimiento para el uso de ubicación',
      ]),
      const SizedBox(height: 16),
      _sectionTitle(context, '6. Retención de datos'),
      _paragraph(context,
          'Conservamos tu información mientras mantengas una cuenta activa. '
          'Al eliminar tu cuenta, tus datos personales serán eliminados en un plazo de 30 días. '
          'Los registros de transacciones se conservan por el período requerido por ley.'),
      const SizedBox(height: 16),
      _sectionTitle(context, '7. Contacto'),
      _paragraph(context,
          'Para consultas sobre privacidad, contáctanos en:\n'
          'Email: info@blackdogpanama.com\n'
          'Teléfono: +507 6000-0000'),
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _termsContent(BuildContext context) {
    return [
      _lastUpdated(context),
      const SizedBox(height: 20),
      _sectionTitle(context, '1. Aceptación de términos'),
      _paragraph(context,
          'Al usar la aplicación de Black Dog Panamá, aceptas estos términos y condiciones. '
          'Si no estás de acuerdo, por favor no utilices la aplicación.'),
      const SizedBox(height: 16),
      _sectionTitle(context, '2. Uso de la aplicación'),
      _paragraph(context,
          'La aplicación te permite explorar productos, realizar pedidos y gestionar tu cuenta. '
          'Debes ser mayor de 18 años o contar con autorización de un tutor legal para realizar compras.'),
      const SizedBox(height: 16),
      _sectionTitle(context, '3. Cuenta de usuario'),
      _bulletList(context, [
        'Eres responsable de mantener la confidencialidad de tu cuenta',
        'La información proporcionada debe ser veraz y actualizada',
        'Nos reservamos el derecho de suspender cuentas que violen estos términos',
      ]),
      const SizedBox(height: 16),
      _sectionTitle(context, '4. Productos y precios'),
      _bulletList(context, [
        'Los precios están en dólares americanos (USD) e incluyen ITBMS cuando aplique',
        'Los precios pueden cambiar sin previo aviso',
        'La disponibilidad de productos está sujeta a stock',
        'Las imágenes son referenciales y pueden variar del producto real',
      ]),
      const SizedBox(height: 16),
      _sectionTitle(context, '5. Pedidos y entregas'),
      _paragraph(context,
          'Al confirmar un pedido, te comprometes a completar el pago. '
          'Los tiempos de entrega son estimados y pueden variar según la zona y disponibilidad. '
          'El costo de envío se muestra antes de confirmar la compra.'),
      const SizedBox(height: 16),
      _sectionTitle(context, '6. Pagos'),
      _paragraph(context,
          'Aceptamos pagos con tarjeta de crédito/débito a través de Tilopay, '
          'así como Yappy y pago en sucursal. '
          'Todas las transacciones son procesadas de forma segura por nuestros proveedores de pago.'),
      const SizedBox(height: 16),
      _sectionTitle(context, '7. Devoluciones y cancelaciones'),
      _bulletList(context, [
        'Puedes cancelar un pedido antes de que sea despachado',
        'Las devoluciones se aceptan dentro de los 7 días posteriores a la entrega',
        'El producto debe estar sin abrir y en su empaque original',
        'Alimentos y productos perecederos no son elegibles para devolución',
      ]),
      const SizedBox(height: 16),
      _sectionTitle(context, '8. Propiedad intelectual'),
      _paragraph(context,
          'Todo el contenido de la aplicación (logos, imágenes, textos, diseño) '
          'es propiedad de Black Dog Panamá y está protegido por leyes de propiedad intelectual.'),
      const SizedBox(height: 16),
      _sectionTitle(context, '9. Limitación de responsabilidad'),
      _paragraph(context,
          'Black Dog Panamá no se hace responsable por daños indirectos derivados del uso de la aplicación. '
          'Nos esforzamos por mantener la información actualizada pero no garantizamos que esté libre de errores.'),
      const SizedBox(height: 16),
      _sectionTitle(context, '10. Contacto'),
      _paragraph(context,
          'Para consultas sobre estos términos:\n'
          'Email: info@blackdogpanama.com\n'
          'Teléfono: +507 6000-0000'),
      const SizedBox(height: 32),
    ];
  }

  Widget _lastUpdated(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Última actualización: Marzo 2026',
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          height: 1.6,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _bulletList(BuildContext context, List<String> items) {
    return Column(
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
