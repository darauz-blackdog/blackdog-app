import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/profile_provider.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

class EditAddressScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> address;

  const EditAddressScreen({super.key, required this.address});

  @override
  ConsumerState<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends ConsumerState<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _zoneCtrl;
  final MapController _mapController = MapController();

  late LatLng _selectedLatLng;
  bool _saving = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    final addr = widget.address;
    _labelCtrl = TextEditingController(text: addr['label'] as String? ?? '');
    _addressCtrl =
        TextEditingController(text: addr['address_line'] as String? ?? '');
    _cityCtrl = TextEditingController(
        text: addr['city'] as String? ?? 'Ciudad de Panamá');
    _zoneCtrl = TextEditingController(text: addr['zone'] as String? ?? '');

    final lat = (addr['latitude'] as num?)?.toDouble() ?? 9.0;
    final lng = (addr['longitude'] as num?)?.toDouble() ?? -79.5;
    _selectedLatLng = LatLng(lat, lng);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateAddress(
        widget.address['id'].toString(),
        label: _labelCtrl.text.trim(),
        addressLine: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        zone: _zoneCtrl.text.trim(),
        latitude: _selectedLatLng.latitude,
        longitude: _selectedLatLng.longitude,
      );
      ref.invalidate(addressesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dirección actualizada')),
        );
        context.pop(true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar dirección'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: _step == 0 ? _buildMapStep() : _buildFormStep(),
    );
  }

  Widget _buildMapStep() {
    return Column(
      children: [
        // Instructions
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mueve el mapa para ajustar la ubicación',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
        // Map
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedLatLng,
                  initialZoom: 16,
                  onPositionChanged: (pos, _) {
                    _selectedLatLng = pos.center;
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                ],
              ),
              // Center pin
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 36),
                  child: Icon(Icons.location_on,
                      size: 48, color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
        // Confirm button
        Padding(
          padding: EdgeInsets.fromLTRB(
              Responsive.padding(context), 12, Responsive.padding(context), 12 + MediaQuery.of(context).padding.bottom),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Confirmar ubicación'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context)),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini map preview
            GestureDetector(
              onTap: () => setState(() => _step = 0),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outline),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: _selectedLatLng,
                          initialZoom: 16,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedLatLng,
                                child: const Icon(Icons.location_on,
                                    size: 36, color: AppColors.error),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Editar',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Etiqueta',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _labelCtrl,
              decoration:
                  const InputDecoration(hintText: 'Ej: Casa, Oficina'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),

            Text('Dirección',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                  hintText: 'Calle, edificio, apartamento'),
              maxLines: 2,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ciudad',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cityCtrl,
                        decoration:
                            const InputDecoration(hintText: 'Ciudad'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zona',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _zoneCtrl,
                        decoration:
                            const InputDecoration(hintText: 'Zona/Barrio'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
