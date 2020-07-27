# Flutter Wrapper - this came from guidance at https://medium.com/@swav.kulinski/flutter-and-android-obfuscation-8768ac544421
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep our class names for gson
-keep class net.defined.mobile_nebula.** { *; }
-keep class androidx.security.crypto.** { *; }