import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );

    final state = ref.read(authNotifierProvider);
    if (state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 320,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Inicia sesión para continuar',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 40),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu correo';
                    if (!v.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showForgotPassword(context),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                const SizedBox(height: 24),

                // Login button
                ElevatedButton(
                  onPressed: isLoading ? null : _handleLogin,
                  child: isLoading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Iniciar Sesión'),
                ),
                const SizedBox(height: 24),

                // Divider
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('o continúa con', style: Theme.of(context).textTheme.bodySmall),
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
                const SizedBox(height: 32),

                // Register link
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('¿No tienes cuenta? ', style: Theme.of(context).textTheme.bodyMedium),
                  TextButton(onPressed: () => context.go('/register'), child: const Text('Regístrate')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPassword(BuildContext context) {
    final emailCtrl = TextEditingController(text: _emailController.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recuperar contraseña', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
                style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(authNotifierProvider.notifier).resetPassword(emailCtrl.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Enlace enviado a tu correo')));
              },
              child: const Text('Enviar enlace'),
            ),
          ],
        ),
      ),
    );
  }
}
