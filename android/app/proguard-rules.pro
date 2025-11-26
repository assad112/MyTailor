# احتفظ ببيانات قد تحتاجها المكتبات (Annotations/Signature)
-keepattributes *Annotation*, Signature, EnclosingMethod, InnerClasses

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Firebase & Google Play Services
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# لو ظهرت تحذيرات play.* بدون استخدام Play Core:
-dontwarn com.google.android.play.**

# Gson
-keep class com.google.gson.** { *; }
-dontwarn sun.misc.**

# OkHttp/Okio/Retrofit (إن وُجدت)
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
# -keep class retrofit2.** { *; }   # فقط إن احتجت
# -dontwarn retrofit2.**
