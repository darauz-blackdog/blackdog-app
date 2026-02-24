import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            // Skip branches without coords or with Miami placeholder addresses
            if (lat == null || lng == null) return false;
            if (address != null && address.contains('NW 35TH')) return false;
            return true;
          }).toList();

          if (branches.isEmpty) {
            return const Center(child: Text('No hay sucursales disponibles'));
          }

          // Center on Panama City
          const defaultCenter = LatLng(9.0, -79.5);

          return Column(
            children: [
              // Map
              SizedBox(
                height: 260,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: defaultCenter,
                    initialZoom: 10.5,
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
                      markers: List.generate(branches.length, (i) {
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
                    ),
                  ],
                ),
              ),

              // Branch count
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
                    return _BranchCard(
                      branch: branch,
                      isSelected: isSelected,
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
  final VoidCallback onTap;
  final VoidCallback onGoogleMaps;
  final VoidCallback onWaze;

  const _BranchCard({
    required this.branch,
    required this.isSelected,
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
            // Name + icon
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
