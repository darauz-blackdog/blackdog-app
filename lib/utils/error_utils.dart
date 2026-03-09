import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Extracts a user-friendly Spanish message from any error.
String friendlyError(Object error) {
  String raw = '';

  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      raw = (data['error'] as String?) ?? (data['message'] as String?) ?? '';
    }
    if (raw.isEmpty) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Tiempo de conexión agotado. Verifica tu internet.';
        case DioExceptionType.connectionError:
          return 'No se pudo conectar al servidor. Verifica tu internet.';
        default:
          break;
      }
    }
  } else if (error is AuthException) {
    raw = error.message;
  } else {
    raw = error.toString().replaceAll('Exception: ', '');
  }

  return _translate(raw);
}

/// Maps known API/Supabase error messages to Spanish.
String _translate(String msg) {
  final lower = msg.toLowerCase();

  // Duplicate email
  if (lower.contains('already registered') ||
      lower.contains('already been registered') ||
      lower.contains('user already exists') ||
      lower.contains('duplicate key') && lower.contains('email')) {
    return 'Este correo ya está registrado. Intenta iniciar sesión.';
  }

  // Duplicate phone
  if (lower.contains('phone') && (lower.contains('already') || lower.contains('duplicate'))) {
    return 'Este número de teléfono ya está registrado.';
  }

  // Invalid credentials
  if (lower.contains('invalid login credentials') || lower.contains('invalid credentials')) {
    return 'Correo o contraseña incorrectos.';
  }

  // Email not confirmed
  if (lower.contains('email not confirmed')) {
    return 'Debes confirmar tu correo antes de iniciar sesión.';
  }

  // Too many requests / rate limit
  if (lower.contains('rate limit') || lower.contains('too many requests')) {
    return 'Demasiados intentos. Espera un momento e intenta de nuevo.';
  }

  // Password too short
  if (lower.contains('password') && lower.contains('at least')) {
    return 'La contraseña debe tener al menos 6 caracteres.';
  }

  // Invalid email
  if (lower.contains('invalid email') || lower.contains('not a valid email')) {
    return 'El correo electrónico no es válido.';
  }

  // Generic network / server
  if (lower.contains('network') || lower.contains('socket')) {
    return 'Error de conexión. Verifica tu internet.';
  }

  // If we have a message but no translation, return it cleaned up
  if (msg.isNotEmpty) return msg;

  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}
