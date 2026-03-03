import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _hasDog = false;
  bool _hasCat = false;
  bool _hasOther = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_formatPhone);
  }

  void _formatPhone() {
    final text = _phoneController.text;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted;
    if (digits.length <= 4) {
      formatted = digits;
    } else {
      formatted = '${digits.substring(0, 4)}-${digits.substring(4, digits.length > 8 ? 8 : digits.length)}';
    }
    if (formatted != text) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_formatPhone);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _fullPhone {
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return '+507$digits';
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

    final petTypes = <String>[
      if (_hasDog) 'perro',
      if (_hasCat) 'gato',
      if (_hasOther) 'otro',
    ];

    await ref.read(authNotifierProvider.notifier).signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: fullName,
          phone: _fullPhone,
          petTypes: petTypes.isNotEmpty ? petTypes : null,
        );

    final state = ref.read(authNotifierProvider);
    if (state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/login')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Crear cuenta', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('Completa tus datos para registrarte',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                // Nombre y Apellido en una fila
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.person_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Apellido',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu correo';
                    if (!v.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Teléfono con +507 pre-set y bandera
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇵🇦', style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(
                            '+507',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    hintText: '6000-0000',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresa tu teléfono';
                    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 7 || digits.length > 8) return 'Teléfono inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleRegister(),
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) => v != _passwordController.text ? 'Las contraseñas no coinciden' : null,
                ),
                const SizedBox(height: 20),
                // Mascotas checkboxes
                Text(
                  '¿Qué mascotas tienes?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: [
                    _PetCheckbox(
                      label: 'Perro',
                      icon: Icons.pets_rounded,
                      value: _hasDog,
                      onChanged: (v) => setState(() => _hasDog = v ?? false),
                    ),
                    _PetCheckbox(
                      label: 'Gato',
                      icon: Icons.pets_rounded,
                      value: _hasCat,
                      onChanged: (v) => setState(() => _hasCat = v ?? false),
                    ),
                    _PetCheckbox(
                      label: 'Otro',
                      icon: Icons.cruelty_free_rounded,
                      value: _hasOther,
                      onChanged: (v) => setState(() => _hasOther = v ?? false),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _handleRegister,
                  child: isLoading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Crear Cuenta'),
                ),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('¿Ya tienes cuenta? ', style: Theme.of(context).textTheme.bodyMedium),
                  TextButton(onPressed: () => context.go('/login'), child: const Text('Inicia Sesión')),
                ]),
                const SizedBox(height: 24),

                // Divider
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('o regístrate con', style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 24),

                // Social buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null
                          : () => ref.read(authNotifierProvider.notifier).signInWithGoogle(),
                      icon: const Icon(Icons.g_mobiledata, size: 24),
                      label: const Text('Google'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null
                          : () => ref.read(authNotifierProvider.notifier).signInWithApple(),
                      icon: const Icon(Icons.apple, size: 24),
                      label: const Text('Apple'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PetCheckbox extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _PetCheckbox({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value ? AppColors.primary : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: value ? AppColors.primary : AppColors.textLight),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                color: value
                    ? AppColors.primary
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
