import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/service_providers.dart';

class AddAddressSheet extends ConsumerStatefulWidget {
  const AddAddressSheet({super.key});

  @override
  ConsumerState<AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Ciudad de Panamá');
  final _zoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nueva dirección',
                    style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Etiqueta *',
                hintText: 'Ej: Casa, Oficina',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección *',
                hintText: 'Calle, edificio, detalle',
              ),
              maxLines: 2,
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(labelText: 'Ciudad'),
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
            const SizedBox(height: 24),
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
                    : const Text('Guardar dirección'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.createAddress(
        label: _labelCtrl.text.trim(),
        addressLine: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        zone: _zoneCtrl.text.trim().isEmpty ? null : _zoneCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}
