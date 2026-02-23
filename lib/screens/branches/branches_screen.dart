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

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sucursales'),
        actions: const [CartBadge(), SizedBox(width: 8)],
      ),
      body: branchesAsync.when(
        data: (branches) {
          if (branches.isEmpty) {
            return const Center(child: Text('No hay sucursales disponibles'));
          }

          // Filter branches with valid coordinates for the map
          final markable = <int>[];
          for (var i = 0; i < branches.length; i++) {
            if (branches[i]['latitude'] != null && branches[i]['longitude'] != null) {
              markable.add(i);
            }
          }

          // Center on Panama City
          const defaultCenter = LatLng(9.0, -79.5);

          return Column(
            children: [
              // Map
              SizedBox(
                height: 280,
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
                      markers: markable.map((i) {
                        final b = branches[i];
                        final isSelected = _selectedIndex == i;
                        return Marker(
                          point: LatLng(
                            b['latitude'] as double,
                            b['longitude'] as double,
                          ),
                          width: isSelected ? 48 : 40,
                          height: isSelected ? 48 : 40,
                          child: GestureDetector(
                            onTap: () => _selectBranch(i, b),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.pets,
                                color: isSelected ? AppColors.secondary : Colors.white,
                                size: isSelected ? 22 : 18,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Branch list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: branches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final branch = branches[index];
                    final isSelected = _selectedIndex == index;
                    return _BranchCard(
                      branch: branch,
                      isSelected: isSelected,
                      onTap: () => _selectBranch(index, branch),
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

  const _BranchCard({
    required this.branch,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = branch['name'] ?? 'Sucursal';
    final address = branch['address'] ?? 'Sin dirección';
    final phone = branch['phone'];
    final wazeUrl = branch['waze_url'];
    final googleMapsUrl = branch['google_maps_url'];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppShadows.soft : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store_mall_directory,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (phone != null)
                  TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Llamar'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                if (googleMapsUrl != null)
                  IconButton(
                    onPressed: () => launchUrl(
                      Uri.parse(googleMapsUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.map, color: AppColors.info),
                    tooltip: 'Google Maps',
                  ),
                if (wazeUrl != null)
                  IconButton(
                    onPressed: () => launchUrl(
                      Uri.parse(wazeUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.directions_car, color: Colors.indigo),
                    tooltip: 'Waze',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
