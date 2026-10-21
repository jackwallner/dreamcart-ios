# RevenueCat publishes consumer ProGuard rules with its Android SDK.
# Credential Manager's Play Services provider is loaded reflectively.
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }
