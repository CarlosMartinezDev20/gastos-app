# Release (R8). google_mlkit_text_recognition references the Chinese,
# Devanagari, Japanese and Korean recognizers, which the app doesn't bundle
# (receipts use the Latin one): don't fail the build on their missing classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
