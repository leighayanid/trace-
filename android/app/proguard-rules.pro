# TRACE — R8 rules.
#
# Kept deliberately short. Only rules for things reflection reaches, which R8
# cannot see: everything else is fair game to shrink.

# flutter_secure_storage reaches androidx.security.crypto, which in turn loads
# Tink primitives by name. Losing these means the token store fails at runtime
# in release and works in debug — the worst kind of difference.
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# The Play Core split-install classes the Flutter embedding references but a
# non-deferred-components build never ships.
-dontwarn com.google.android.play.core.**
