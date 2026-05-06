# Flutter / Dart
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Supabase / GoTrue / PostgREST
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }
-dontwarn io.supabase.**

# OkHttp (used by Dio)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Dio
-keep class io.objectbox.** { *; }

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.api.client.** { *; }

# Flutter Secure Storage (uses Android Keystore)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# WebView Flutter
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# flutter_map / OSM tile caching
-keep class com.github.mkobi.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# General reflection keep rules
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
