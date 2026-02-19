import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cart_badge.dart';

final branchesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getBranches();
});

class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sucursales'),
        actions: const [
          CartBadge(),
          SizedBox(width: 8),
        ],
      ),
      body: branchesAsync.when(
        data: (branches) {
          if (branches.isEmpty) {
            return const Center(child: Text('No hay sucursales disponibles'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: branches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final branch = branches[index];
              return _BranchCard(branch: branch);
            },
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

  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    final name = branch['name'] ?? 'Sucursal';
    final address = branch['address'] ?? 'Sin dirección';
    final phone = branch['phone'];
    final wazeUrl = branch['waze_url'];
    final googleMapsUrl = branch['google_maps_url'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.store_mall_directory, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (phone != null)
                  TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Llamar'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  ),
                if (googleMapsUrl != null)
                  IconButton(
                    onPressed: () => launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.map, color: Colors.blue),
                    tooltip: 'Google Maps',
                  ),
                if (wazeUrl != null)
                  IconButton(
                    onPressed: () => launchUrl(Uri.parse(wazeUrl), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.directions_car, color: Colors.indigo), // Waze-ish
                    tooltip: 'Waze',
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
