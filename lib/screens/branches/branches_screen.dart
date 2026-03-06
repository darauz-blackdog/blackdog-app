import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/location_provider.dart';
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
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  int? _selectedIndex;
  bool _didInitialMove = false;
  bool _didZoomToNearest = false;
  bool _mapReady = false;

  void _zoomToNearestBranch(Position position, List<dynamic> branches) {
    if (branches.isEmpty) return;

    double? minDist;
    Map<String, dynamic>? nearest;
    int nearestIndex = 0;

    for (int i = 0; i < branches.length; i++) {
      final b = branches[i] as Map<String, dynamic>;
      final lat = b['latitude'] as double?;
      final lng = b['longitude'] as double?;
      if (lat == null || lng == null) continue;

      const distance = Distance();
      final d = distance.as(
        LengthUnit.Kilometer,
        LatLng(position.latitude, position.longitude),
        LatLng(lat, lng),
      );
      if (minDist == null || d < minDist) {
        minDist = d;
        nearest = b;
        nearestIndex = i;
      }
    }

    if (nearest != null) {
      try {
        _mapController.move(
          LatLng(nearest['latitude'] as double, nearest['longitude'] as double),
          15.0,
        );
        setState(() => _selectedIndex = nearestIndex);
      } catch (_) {}
    }
  }

  double? _distanceKm(Map<String, dynamic> branch, Position? userPosition) {
    if (userPosition == null) return null;
    final lat = branch['latitude'] as double?;
    final lng = branch['longitude'] as double?;
    if (lat == null || lng == null) return null;
    const distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      LatLng(userPosition.latitude, userPosition.longitude),
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

  List<dynamic> _filterAndSort(List<dynamic> allBranches, Position? userPosition) {
    final branches = allBranches.where((b) {
      final lat = b['latitude'] as double?;
      final lng = b['longitude'] as double?;
      final address = b['address'] as String?;
      if (lat == null || lng == null) return false;
      if (address != null && address.contains('NW 35TH')) return false;
      return true;
    }).toList();

    if (userPosition != null) {
      branches.sort((a, b) {
        final dA = _distanceKm(a, userPosition) ?? double.infinity;
        final dB = _distanceKm(b, userPosition) ?? double.infinity;
        return dA.compareTo(dB);
      });
    }

    return branches;
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesProvider);
    final userPosAsync = ref.watch(userLocationProvider);
    final userPosition = userPosAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset('assets/icons/Black_Dog_Logo_V.png'),
        ),
        title: const Text('Sucursales'),
        actions: const [CartBadge(), SizedBox(width: 8)],
      ),
      body: branchesAsync.when(
        data: (allBranches) {
          final branches = _filterAndSort(allBranches, userPosition);

          if (branches.isEmpty) {
            return const Center(child: Text('No hay sucursales disponibles'));
          }

          final mapCenter = userPosition != null
              ? LatLng(userPosition.latitude, userPosition.longitude)
              : const LatLng(9.0, -79.5);
          final mapZoom = userPosition != null ? 12.0 : 10.5;

          // Move map after it's ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_mapReady) return;
            if (!_didInitialMove) {
              _didInitialMove = true;
              _mapController.move(mapCenter, mapZoom);
            }
            if (userPosition != null && !_didZoomToNearest) {
              _didZoomToNearest = true;
              _zoomToNearestBranch(userPosition, branches);
            }
          });

          return Stack(
            children: [
              // Full-screen map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: mapZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    _mapReady = true;
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        Theme.of(context).brightness == Brightness.dark
                            ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
                            : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
                    userAgentPackageName: 'com.blackdogpanama.blackdog_app',
                  ),
                  MarkerLayer(
                    markers: [
                      if (userPosition != null)
                        Marker(
                          point: LatLng(
                            userPosition.latitude,
                            userPosition.longitude,
                          ),
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
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
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Image.asset(
                                  'assets/icons/Logo_Head.png',
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),

              // Draggable bottom sheet
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: 0.18,
                minChildSize: 0.08,
                maxChildSize: 0.75,
                snap: true,
                snapSizes: const [0.18, 0.45, 0.75],
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: branches.length + 1, // +1 for header
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildSheetHeader(branches, userPosition);
                        }
                        final branchIndex = index - 1;
                        final branch =
                            branches[branchIndex] as Map<String, dynamic>;
                        final isSelected = _selectedIndex == branchIndex;
                        final dist = _distanceKm(branch, userPosition);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          child: _BranchCard(
                            branch: branch,
                            isSelected: isSelected,
                            distanceKm: dist,
                            formatDistance:
                                dist != null ? _formatDistance(dist) : null,
                            onTap: () {
                              _selectBranch(branchIndex, branch);
                              // Collapse sheet a bit when selecting
                              _sheetController.animateTo(
                                0.18,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                            onGoogleMaps: () => _openGoogleMaps(
                              branch['latitude'] as double,
                              branch['longitude'] as double,
                            ),
                            onWaze: () => _openWaze(
                              branch['latitude'] as double,
                              branch['longitude'] as double,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSheetHeader(List<dynamic> branches, Position? userPosition) {
    final nearest =
        branches.isNotEmpty ? branches[0] as Map<String, dynamic> : null;
    final nearestDist =
        nearest != null ? _distanceKm(nearest, userPosition) : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),

        // Nearest branch preview card
        if (nearest != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () {
                _selectBranch(0, nearest);
                _sheetController.animateTo(
                  0.18,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.store,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nearest['name'] ?? 'Sucursal',
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          nearestDist != null
                              ? 'Mas cercana - ${_formatDistance(nearestDist)}'
                              : '${branches.length} sucursales',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (nearestDist != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDistance(nearestDist),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Divider before full list
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${branches.length} sucursales',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (userPosition != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Por cercanía',
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
        Divider(
          color:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          height: 1,
        ),
        const SizedBox(height: 4),
      ],
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
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppShadows.soft : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me,
                            size: 12, color: AppColors.primary),
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
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 16, color: AppColors.textSecondary),
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
            if (email != null && email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      email,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
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
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onWaze,
                    icon:
                        const Icon(Icons.directions_car_outlined, size: 16),
                    label: const Text('Waze'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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
