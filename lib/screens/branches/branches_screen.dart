import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_badge.dart';

final branchesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getBranches();
});

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  final MapController _mapController = MapController();
  int? _selectedIndex;
  Position? _userPosition;
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          setState(() => _locationLoading = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _userPosition = position;
          _locationLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  double? _distanceKm(Map<String, dynamic> branch) {
    if (_userPosition == null) return null;
    final lat = branch['latitude'] as double?;
    final lng = branch['longitude'] as double?;
    if (lat == null || lng == null) return null;
    const distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      LatLng(_userPosition!.latitude, _userPosition!.longitude),
      LatLng(lat, lng),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  void _selectBranch(int index, Map<String, dynamic> branch) {
    final lat = branch['latitude'] as double?;
    final lng = branch['longitude'] as double?;
    if (lat == null || lng == null) return;

    setState(() => _selectedIndex = index);
    _mapController.move(LatLng(lat, lng), 15);
  }

  void _openGoogleMaps(double lat, double lng) {
    launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _openWaze(double lat, double lng) {
    launchUrl(
      Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sucursales'),
        actions: const [CartBadge(), SizedBox(width: 8)],
      ),
      body: branchesAsync.when(
        data: (allBranches) {
          // Filter out branches without valid coordinates or with placeholder data
          final branches = allBranches.where((b) {
            final lat = b['latitude'] as double?;
            final lng = b['longitude'] as double?;
            final address = b['address'] as String?;
            if (lat == null || lng == null) return false;
            if (address != null && address.contains('NW 35TH')) return false;
            return true;
          }).toList();

          if (branches.isEmpty) {
            return const Center(child: Text('No hay sucursales disponibles'));
          }

          // Sort by distance if user location is available
          if (_userPosition != null) {
            branches.sort((a, b) {
              final dA = _distanceKm(a) ?? double.infinity;
              final dB = _distanceKm(b) ?? double.infinity;
              return dA.compareTo(dB);
            });
          }

          // Center on user location or Panama City
          final mapCenter = _userPosition != null
              ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
              : const LatLng(9.0, -79.5);
          final mapZoom = _userPosition != null ? 12.0 : 10.5;

          return Column(
            children: [
              // Map
              SizedBox(
                height: 260,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: mapZoom,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.blackdog.app',
                    ),
                    MarkerLayer(
                      markers: [
                        // User location marker
                        if (_userPosition != null)
                          Marker(
                            point: LatLng(
                              _userPosition!.latitude,
                              _userPosition!.longitude,
                            ),
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Branch markers
                        ...List.generate(branches.length, (i) {
                          final b = branches[i];
                          final isSelected = _selectedIndex == i;
                          return Marker(
                            point: LatLng(
                              b['latitude'] as double,
                              b['longitude'] as double,
                            ),
                            width: isSelected ? 46 : 38,
                            height: isSelected ? 46 : 38,
                            child: GestureDetector(
                              onTap: () => _selectBranch(i, b),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : AppColors.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.pets,
                                  color: isSelected ? AppColors.secondary : Colors.white,
                                  size: isSelected ? 20 : 16,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              // Branch count + location status
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      '${branches.length} sucursales',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (_locationLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textLight,
                        ),
                      )
                    else if (_userPosition != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            'Ordenado por cercanía',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Branch list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: branches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final branch = branches[index] as Map<String, dynamic>;
                    final isSelected = _selectedIndex == index;
                    final dist = _distanceKm(branch);
                    return _BranchCard(
                      branch: branch,
                      isSelected: isSelected,
                      distanceKm: dist,
                      formatDistance: dist != null ? _formatDistance(dist) : null,
                      onTap: () => _selectBranch(index, branch),
                      onGoogleMaps: () => _openGoogleMaps(
                        branch['latitude'] as double,
                        branch['longitude'] as double,
                      ),
                      onWaze: () => _openWaze(
                        branch['latitude'] as double,
                        branch['longitude'] as double,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;
  final bool isSelected;
  final double? distanceKm;
  final String? formatDistance;
  final VoidCallback onTap;
  final VoidCallback onGoogleMaps;
  final VoidCallback onWaze;

  const _BranchCard({
    required this.branch,
    required this.isSelected,
    this.distanceKm,
    this.formatDistance,
    required this.onTap,
    required this.onGoogleMaps,
    required this.onWaze,
  });

  @override
  Widget build(BuildContext context) {
    final name = branch['name'] ?? 'Sucursal';
    final address = branch['address'] as String?;
    final city = branch['city'] as String?;
    final phone = branch['phone'] as String?;
    final email = branch['email'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppShadows.soft : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + icon + distance
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (city != null && city.isNotEmpty)
                        Text(
                          city.replaceAll('.', ''),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
                if (formatDistance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          formatDistance!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Address
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Phone
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse('tel:$phone')),
                    child: Text(
                      phone,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Email
            if (email != null && email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      email,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Navigation buttons
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGoogleMaps,
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Google Maps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onWaze,
                    icon: const Icon(Icons.directions_car_outlined, size: 16),
                    label: const Text('Waze'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
