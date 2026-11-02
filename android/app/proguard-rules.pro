# The app only uses Latin-script text recognition (plates). The ML Kit plugin
# references the optional Chinese/Devanagari/Japanese/Korean recognizers,
# which are not bundled; without these rules R8 fails the release build.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
