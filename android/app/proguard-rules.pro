# Flutter saját ProGuard szabályai már beépítve a Flutter Gradle plugin-ban.
# Itt csak a használt natív / reflection-alapú könyvtáraknak kell külön szabályt írni.

# ── Flutter embedding ─────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Kotlin metadata (reflection-alapú lib-ek igényelhetik) ────────────
-keep class kotlin.Metadata { *; }
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations
-keepattributes Signature,InnerClasses,EnclosingMethod

# ── Kotlinx Coroutines (háttér OBD kapcsolat a ForegroundService-ben) ─
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ── Saját Kotlin osztályok (BroadcastReceiver, Service) ───────────────
-keep class com.example.obdreader2.** { *; }

# ── Bluetooth Classic (flutter_bluetooth_serial) ──────────────────────
-keep class io.github.edufolly.flutterbluetoothserial.** { *; }

# ── BLE (flutter_blue_plus) ───────────────────────────────────────────
-keep class com.lib.flutter_blue_plus.** { *; }

# ── Drift (SQLite ORM) – generated code ───────────────────────────────
-keep class drift.** { *; }
-keep class **$$Generated { *; }

# ── Geolocator ─────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }

# ── flutter_local_notifications ───────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ── Fl_chart, fl_chart_app stb. nem reflection-alapú, nem kell külön szabály.

# ── Plain crash log barát ──────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Ne dobja ki a logot (hibaelhárításhoz hasznos).
-dontwarn javax.annotation.**
-dontwarn org.jetbrains.annotations.**
