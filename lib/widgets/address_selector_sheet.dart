import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/address_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';

Future<void> showAddressSelectorSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AddressSelectorContent(),
  );
}

class _AddressSelectorContent extends ConsumerWidget {
  const _AddressSelectorContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);
    final selected = ref.watch(selectedAddressProvider).valueOrNull;
    final branches = ref.watch(branchListProvider).valueOrNull ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dirección de entrega',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final result = await context.push<bool>(
                        '/profile/addresses/add',
                      );
                      if (result == true) {
                        ref.invalidate(addressesProvider);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nueva'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: addressesAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off_outlined,
                              size: 48,
                              color: Theme.of(context).hintColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tienes direcciones guardadas',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Agrega una para calcular tu sucursal más cercana',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                    itemBuilder: (context, i) {
                      final addr = list[i] as Map<String, dynamic>;
                      final id = addr['id'] as String;
                      final label = addr['label'] as String? ?? 'Dirección';
                      final line = addr['address_line'] as String? ?? '';
                      final lat = (addr['latitude'] as num?)?.toDouble();
                      final lng = (addr['longitude'] as num?)?.toDouble();
                      final isSelected = selected?.id == id;

                      // Calculate nearest branch for this address
                      String? branchInfo;
                      bool? deliveryAvailable;
                      if (lat != null && lng != null && branches.isNotEmpty) {
                        double minDist = double.infinity;
                        String? nearestName;
                        for (final b in branches) {
                          if (b.latitude == null || b.longitude == null) {
                            continue;
                          }
                          final d = _haversineKm(
                            lat, lng, b.latitude!, b.longitude!,
                          );
                          if (d < minDist) {
                            minDist = d;
                            nearestName = b.name;
                          }
                        }
                        if (nearestName != null) {
                          deliveryAvailable = minDist <= 2.0;
                          branchInfo =
                              '$nearestName (${minDist.toStringAsFixed(1)} km)';
                        }
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: isSelected
                                ? AppColors.primary
                                : Theme.of(context).hintColor,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (line.isNotEmpty)
                              Text(
                                line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (branchInfo != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.store_outlined,
                                    size: 14,
                                    color: deliveryAvailable == true
                                        ? AppColors.primary
                                        : Theme.of(context).hintColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      deliveryAvailable == true
                                          ? branchInfo
                                          : '$branchInfo — Solo recogida',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: deliveryAvailable == true
                                                ? AppColors.primary
                                                : Theme.of(context).hintColor,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () {
                          if (lat != null && lng != null) {
                            ref
                                .read(selectedAddressProvider.notifier)
                                .selectAddress(SelectedAddress(
                                  id: id,
                                  label: label,
                                  addressLine: line,
                                  latitude: lat,
                                  longitude: lng,
                                ));
                          }
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(
                  child: Text('Error cargando direcciones'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * (math.pi / 180);
  final dLon = (lon2 - lon1) * (math.pi / 180);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * (math.pi / 180)) *
          math.cos(lat2 * (math.pi / 180)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
