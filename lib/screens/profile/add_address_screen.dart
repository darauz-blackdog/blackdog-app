import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../utils/responsive.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Ciudad de Panamá');
  final _zoneCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final MapController _mapController = MapController();

  LatLng _selectedLatLng = const LatLng(9.0, -79.5); // Panama City default
  bool _locationLoading = true;
  bool _saving = false;
  bool _mapReady = false;
  int _step = 0; // 0 = map picker, 1 = form details

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _zoneCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) setState(() => _locationLoading = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        final userLatLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _selectedLatLng = userLatLng;
          _locationLoading = false;
        });
        if (_mapReady) {
          _mapController.move(userLatLng, 16.0);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _centerOnUser() async {
    setState(() => _locationLoading = true);
    await _getUserLocation();
    if (_mapReady && mounted) {
      _mapController.move(_selectedLatLng, 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step = 0);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(_step == 0 ? 'Ubicación en el mapa' : 'Detalles de dirección'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _step == 0
            ? _buildMapStep(key: const ValueKey('map'))
            : _buildFormStep(key: const ValueKey('form')),
      ),
    );
  }

  // ── Step 0: Map Picker ──────────────────────────────────────────

  Widget _buildMapStep({Key? key}) {
    return Column(
      key: key,
      children: [
        // Instructions
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: Responsive.padding(context), vertical: 12),
          color: AppColors.primary.withValues(alpha: 0.08),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mueve el mapa para posicionar el pin en tu dirección',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
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
                  initialZoom: _locationLoading ? 12.0 : 16.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (position, hasGesture) {
                    _selectedLatLng = position.center;
                  },
                  onMapReady: () {
                    _mapReady = true;
                    if (!_locationLoading) {
                      _mapController.move(_selectedLatLng, 16.0);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.blackdog.app',
                  ),
                ],
              ),

              // Center pin (fixed overlay)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Icon(
                    Icons.location_pin,
                    size: 48,
                    color: AppColors.primary,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Pin shadow dot
              Center(
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Loading indicator
              if (_locationLoading)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Obteniendo ubicación...',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

              // Locate me button
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.small(
                  heroTag: 'locate_me',
                  onPressed: _centerOnUser,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.info,
                  elevation: 4,
                  child: const Icon(Icons.my_location),
                ),
              ),

              // Coordinates badge
              Positioned(
                left: 16,
                bottom: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Text(
                    '${_selectedLatLng.latitude.toStringAsFixed(5)}, ${_selectedLatLng.longitude.toStringAsFixed(5)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Confirm location button
        Container(
          padding: EdgeInsets.all(Responsive.padding(context)),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color:
                    Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _step = 1),
                icon: const Icon(Icons.check),
                label: const Text('Confirmar ubicación'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 1: Address Details Form ─────────────────────────────────

  Widget _buildFormStep({Key? key}) {
    return Column(
      key: key,
      children: [
        // Mini map preview
        SizedBox(
          height: 120,
          width: double.infinity,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: _selectedLatLng,
                  initialZoom: 15.0,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.blackdog.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLatLng,
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_pin,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Edit location button
              Positioned(
                right: 12,
                bottom: 12,
                child: GestureDetector(
                  onTap: () => setState(() => _step = 0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_location_alt,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Editar',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Form
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.padding(context)),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalles de la dirección',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Completa los datos para facilitar la entrega',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Label
                  TextFormField(
                    controller: _labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Etiqueta *',
                      hintText: 'Ej: Casa, Oficina, Apartamento',
                      prefixIcon: Icon(Icons.label_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),

                  // Address line
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección *',
                      hintText: 'Calle, edificio, piso, apto',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    maxLines: 2,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),

                  // City + Zone
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ciudad',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _zoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Zona / Barrio',
                            hintText: 'Ej: San Francisco',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reference
                  TextFormField(
                    controller: _referenceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Punto de referencia (opcional)',
                      hintText: 'Ej: Frente al parque, casa azul',
                      prefixIcon: Icon(Icons.near_me_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // Save button
        Container(
          padding: EdgeInsets.all(Responsive.padding(context)),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color:
                    Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar dirección'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final api = ref.read(apiServiceProvider);
      final addressLine = _referenceCtrl.text.trim().isNotEmpty
          ? '${_addressCtrl.text.trim()} (${_referenceCtrl.text.trim()})'
          : _addressCtrl.text.trim();

      await api.createAddress(
        label: _labelCtrl.text.trim(),
        addressLine: addressLine,
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        zone: _zoneCtrl.text.trim().isEmpty ? null : _zoneCtrl.text.trim(),
        latitude: _selectedLatLng.latitude,
        longitude: _selectedLatLng.longitude,
      );
      if (mounted) context.pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
