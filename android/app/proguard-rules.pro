# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /Users/todd/Library/Android/sdk/tools/proguard/proguard-android.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Add any project specific keep options here:

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Don't obfuscate so that logs contain useful stack traces
-dontobfuscate
#-keep class com.microtripit.** { *; }
#-keep class com.microtripit.mandrillapp.**
-keepattributes Signature

#-keep class android.** { *; }
# Make sure we get line numbers in stack traces, but don't reveal source file names
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider