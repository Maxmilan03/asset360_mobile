# Flutter engine + plugin registrant (the Flutter Gradle plugin adds its own rules too).
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter references Play Core (deferred components) that this app doesn't ship.
-dontwarn com.google.android.play.core.**

# ML Kit / Play services barcode scanning (mobile_scanner).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode** { *; }
-dontwarn com.google.mlkit.**

# Plugins that talk to Flutter over Pigeon / method channels.
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class io.scer.pdfx.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }
-keep class dev.flutter.pigeon.** { *; }
