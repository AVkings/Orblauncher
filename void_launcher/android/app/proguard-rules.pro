# Flutter handles its own keeps; nothing extra needed for the bridge
# (MethodChannel uses reflection-free string dispatch).
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
