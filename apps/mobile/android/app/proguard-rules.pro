# ═══════════════════════════════════════════════════════════════════
# EPI Supervisor — ProGuard Rules
# ═══════════════════════════════════════════════════════════════════
# These rules protect classes/methods from being removed or obfuscated
# during release builds. Without them, the app will crash at runtime.

# ─── Flutter Core ─────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Dart/Flutter Method Channel ─────────────────────────────────
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.plugin.common.** { *; }

# ─── Supabase ────────────────────────────────────────────────────
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# ─── Kotlin Coroutines (used by Supabase) ────────────────────────
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
-keep class kotlin.coroutines.** { *; }

# ─── Gson / JSON Serialization ───────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Keep all model classes that are serialized/deserialized
-keep class * implements java.io.Serializable { *; }

# ─── Sentry ──────────────────────────────────────────────────────
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**
-keepattributes LineNumberTable,SourceFile

# ─── Google Play Services ────────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─── Google Play Core (Flutter deferred components) ──────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ─── Geolocator Plugin ──────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ─── Image Picker ───────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# ─── Connectivity Plus ──────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# ─── Permission Handler ─────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ─── URL Launcher ────────────────────────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

# ─── Share Plus ──────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

# ─── Path Provider ───────────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# ─── Hive (Local Database) ──────────────────────────────────────
-keep class com.google.errorprone.annotations.** { *; }
-dontwarn com.google.errorprone.annotations.**

# ─── Cached Network Image ───────────────────────────────────────
-keep class com.example.cachednetworkimage.** { *; }

# ─── Location/Maps Plugins ──────────────────────────────────────
-keep class com.google.maps.** { *; }
-dontwarn com.google.maps.**

# ─── Preserve annotations needed at runtime ─────────────────────
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# ─── General Android ─────────────────────────────────────────────
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepclassmembers class **.R$* {
    public static <fields>;
}

# ─── Keep native methods ────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ─── Prevent stripping of enum methods ──────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ─── Optimization settings ──────────────────────────────────────
-optimizations !code/simplification/arithmetic
-allowaccessmodification
-repackageclasses ''
