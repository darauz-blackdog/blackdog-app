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
import '../../utils/responsive.dart';
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
  final ScrollController _sideListController = ScrollController();
  int? _selectedIndex;
  bool _didInitialMove = false;
  bool _didZoomToNearest = false;
  bool _mapReady = false;
  String _searchQuery = '';
  bool _sheetExpanded = false;

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
          LatLng(
              nearest['latitude'] as double, nearest['longitude'] as double),
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
    _scrollToSelected(index);
  }

  void _scrollToSelected(int index) {
    // For side panel layout
    if (_sideListController.hasClients) {
      final target = index * 160.0; // approximate card height
      _sideListController.animateTo(
        target.clamp(0, _sideListController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _fitAllMarkers(List<dynamic> branches, Position? userPosition) {
    final points = <LatLng>[];
    for (final b in branches) {
      final lat = b['latitude'] as double?;
      final lng = b['longitude'] as double?;
      if (lat != null && lng != null) points.add(LatLng(lat, lng));
    }
    if (userPosition != null) {
      points.add(LatLng(userPosition.latitude, userPosition.longitude));
    }
    if (points.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(points);
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
      setState(() => _selectedIndex = null);
    } catch (_) {}
  }

  void _openGoogleMaps(double lat, double lng) {
    launchUrl(
      Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _openWaze(double lat, double lng) {
    launchUrl(
      Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
      mode: LaunchMode.externalApplication,
    );
  }

  List<dynamic> _filterAndSort(
      List<dynamic> allBranches, Position? userPosition) {
    var branches = allBranches.where((b) {
      final lat = b['latitude'] as double?;
      final lng = b['longitude'] as double?;
      final address = b['address'] as String?;
      if (lat == null || lng == null) return false;
      if (address != null && address.contains('NW 35TH')) return false;
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      branches = branches.where((b) {
        final name = (b['name'] as String? ?? '').toLowerCase();
        final city = (b['city'] as String? ?? '').toLowerCase();
        final address = (b['address'] as String? ?? '').toLowerCase();
        return name.contains(q) || city.contains(q) || address.contains(q);
      }).toList();
    }

    if (userPosition != null) {
      branches.sort((a, b) {
        final dA = _distanceKm(a, userPosition) ?? double.infinity;
        final dB = _distanceKm(b, userPosition) ?? double.infinity;
        return dA.compareTo(dB);
      });
    }

    return branches;
  }

  void _toggleSheet() {
    setState(() => _sheetExpanded = !_sheetExpanded);
  }

  @override
  void dispose() {
    _sideListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesProvider);
    final userPosAsync = ref.watch(userLocationProvider);
    final userPosition = userPosAsync.valueOrNull;
    final isWide = Responsive.isExpanded(context);

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

          final mapCenter = userPosition != null
              ? LatLng(userPosition.latitude, userPosition.longitude)
              : const LatLng(9.0, -79.5);
          final mapZoom = userPosition != null ? 12.0 : 10.5;

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

          final mapWidget = _buildMap(branches, userPosition, mapCenter, mapZoom);

          if (isWide) {
            return _buildWideLayout(mapWidget, branches, userPosition);
          }
          return _buildNarrowLayout(mapWidget, branches, userPosition);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  // ── Map widget (shared) ──────────────────────────────────────────────

  Widget _buildMap(List<dynamic> branches, Position? userPosition,
      LatLng center, double zoom) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _mapReady = true,
      ),
      children: [
        TileLayer(
          urlTemplate: Theme.of(context).brightness == Brightness.dark
              ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
              : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
          userAgentPackageName: 'com.blackdogpanama.blackdog_app',
        ),
        MarkerLayer(
          markers: [
            if (userPosition != null)
              Marker(
                point: LatLng(
                    userPosition.latitude, userPosition.longitude),
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
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
              final markerSize =
                  Responsive.isExpanded(context) ? 44.0 : 38.0;
              final selectedSize = markerSize + 8;
              return Marker(
                point: LatLng(
                  b['latitude'] as double,
                  b['longitude'] as double,
                ),
                width: isSelected ? selectedSize : markerSize,
                height: isSelected ? selectedSize : markerSize,
                child: GestureDetector(
                  onTap: () => _selectBranch(i, b),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.secondary,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child:
                          Image.asset('assets/icons/Logo_Head.png'),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── FABs over the map ────────────────────────────────────────────────

  Widget _buildMapFabs(
      List<dynamic> branches, Position? userPosition, double bottomOffset) {
    return Positioned(
      right: Responsive.paddingSmall(context),
      bottom: bottomOffset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fit all markers
          FloatingActionButton.small(
            heroTag: 'fitAll',
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            elevation: 4,
            onPressed: () => _fitAllMarkers(branches, userPosition),
            child: const Icon(Icons.zoom_out_map),
          ),
          if (userPosition != null) ...[
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: AppColors.primary,
              elevation: 4,
              onPressed: () {
                _mapController.move(
                  LatLng(
                      userPosition.latitude, userPosition.longitude),
                  15.0,
                );
                setState(() => _selectedIndex = null);
              },
              child: const Icon(Icons.my_location),
            ),
          ],
        ],
      ),
    );
  }

  // ── Narrow layout (phone): map + sliding bottom panel ─────────────

  Widget _buildNarrowLayout(
      Widget mapWidget, List<dynamic> branches, Position? userPosition) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final expandedHeight = screenHeight * 0.65;
    // Collapsed: header only (~76px). Expanded: 65% of screen.
    final panelHeight = _sheetExpanded ? expandedHeight : 76.0;

    return Stack(
      children: [
        Positioned.fill(child: mapWidget),
        _buildMapFabs(branches, userPosition, panelHeight + 12),
        // Bottom panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: 0,
          height: panelHeight,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.velocity.pixelsPerSecond.dy < -200) {
                setState(() => _sheetExpanded = true);
              } else if (details.velocity.pixelsPerSecond.dy > 200) {
                setState(() => _sheetExpanded = false);
              }
            },
            child: Container(
              clipBehavior: Clip.hardEdge,
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
              child: Column(
                mainAxisSize: _sheetExpanded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  _buildCollapsedHeader(branches, userPosition),
                  if (_sheetExpanded)
                    Expanded(
                      child: Column(
                        children: [
                          _buildSearchField(),
                          const SizedBox(height: 4),
                        Expanded(
                          child: branches.isEmpty
                              ? Center(
                                  child: Text(
                                    'Sin resultados',
                                    style: GoogleFonts.inter(
                                        color: AppColors.textLight),
                                  ),
                                )
                              : ListView.builder(
                                  padding: EdgeInsets.only(
                                    left: Responsive.paddingSmall(context),
                                    right: Responsive.paddingSmall(context),
                                    bottom: MediaQuery.paddingOf(context)
                                            .bottom +
                                        8,
                                  ),
                                  itemCount: branches.length,
                                  itemBuilder: (context, index) {
                                    final branch = branches[index]
                                        as Map<String, dynamic>;
                                    final isSelected =
                                        _selectedIndex == index;
                                    final dist =
                                        _distanceKm(branch, userPosition);
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 10),
                                      child: _BranchCard(
                                        branch: branch,
                                        isSelected: isSelected,
                                        distanceKm: dist,
                                        formatDistance: dist != null
                                            ? _formatDistance(dist)
                                            : null,
                                        onTap: () {
                                          _selectBranch(index, branch);
                                          setState(() =>
                                              _sheetExpanded = false);
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Collapsed header (always visible in narrow) ──────────────────────

  Widget _buildCollapsedHeader(
      List<dynamic> branches, Position? userPosition) {
    return GestureDetector(
      onTap: _toggleSheet,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.paddingSmall(context),
          vertical: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.store,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${branches.length} sucursales',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (userPosition != null)
                  Text(
                    'Ordenadas por cercania',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _sheetExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Wide layout (tablet): map + side panel ───────────────────────────

  Widget _buildWideLayout(
      Widget mapWidget, List<dynamic> branches, Position? userPosition) {
    return Row(
      children: [
        // Map takes remaining space
        Expanded(
          child: Stack(
            children: [
              mapWidget,
              _buildMapFabs(branches, userPosition, 16),
            ],
          ),
        ),
        // Side panel
        SizedBox(
          width: 360,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                left: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                _buildSearchField(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              'Por cercania',
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
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                ),
                Expanded(
                  child: branches.isEmpty
                      ? Center(
                          child: Text(
                            'Sin resultados',
                            style: GoogleFonts.inter(
                              color: AppColors.textLight,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _sideListController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: branches.length,
                          itemBuilder: (context, index) {
                            final branch =
                                branches[index] as Map<String, dynamic>;
                            final isSelected = _selectedIndex == index;
                            final dist = _distanceKm(branch, userPosition);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              child: _BranchCard(
                                branch: branch,
                                isSelected: isSelected,
                                distanceKm: dist,
                                formatDistance: dist != null
                                    ? _formatDistance(dist)
                                    : null,
                                onTap: () =>
                                    _selectBranch(index, branch),
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Search field ─────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar sucursal...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).hintColor,
          ),
          prefixIcon:
              Icon(Icons.search, size: 20, color: Theme.of(context).hintColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
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
                    icon: const Icon(Icons.directions_car_outlined,
                        size: 16),
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
