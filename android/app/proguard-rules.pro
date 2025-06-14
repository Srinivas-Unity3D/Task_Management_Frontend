# Keep AndroidX Window and Sidecar classes
-keep class androidx.window.** { *; }
-keep interface androidx.window.** { *; }
-dontwarn androidx.window.**

-keep class androidx.window.extensions.** { *; }
-keep interface androidx.window.extensions.** { *; }
-dontwarn androidx.window.extensions.**

-keep class androidx.window.sidecar.** { *; }
-keep interface androidx.window.sidecar.** { *; }
-dontwarn androidx.window.sidecar.**
