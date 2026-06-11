# Stealth-build ProGuard/R8 rules.
#
# This file REPLACES proguard-rules.pro for stealth builds (setProguardFiles in
# build.gradle).  It is intentionally different in one critical way:
#
#   proguard-rules.pro has  -dontobfuscate  (keeps every class name as-is).
#   This file omits that flag and adds  -repackageclasses 'f'  instead, so R8
#   repackages any residual  org.getlantern.lantern.*  classes that slip through
#   the KotlinCompile exclusion into the neutral package 'f'.
#
# Primary de-branding is done at compile time:
#   - KotlinCompile excludes org/getlantern/** for stealth builds.
#   - Alternate source sets (foundation.bridge.*) replace every manifest-
#     referenced class (AppHost, HomeActivity, NetworkService, SyncService).
#   - namespace = "foundation.bridge" → R.class and BuildConfig are neutral.
#   - gomobile is built with -javapkg=foundation.engine → no lantern.io.* stubs.
#
# -repackageclasses is a belt-and-suspenders safety net for library AARs or
# any Java source that the Kotlin exclusion task does not cover.
#
# Normal (non-stealth) builds are UNAFFECTED — they still use proguard-rules.pro.

-keepattributes Signature
-keepattributes SourceFile,LineNumberTable,*Annotation*,InnerClasses
-renamesourcefileattribute SourceFile

# ── Namespace repackaging (the key stealth rule) ────────────────────────────
# Repackage residual org.getlantern.lantern.* classes to package 'f'.
-repackageclasses 'f'
-allowaccessmodification

# ── Manifest-referenced components ──────────────────────────────────────────
# android_manifest_filter.py (--mode stealth / --mode novpn) rewrites every
# manifest android:name reference to the foundation.bridge.* FQN.  R8 must
# keep these classes at their exact names so the runtime can find them.
-keep class foundation.bridge.** { *; }

# ── gomobile JNI stubs (stealth javapkg = foundation.engine) ─────────────────
# The Go layer calls into Java via JNI using symbol names derived from the Java
# package at gomobile build time.  With GOMOBILE_JAVAPKG=foundation.engine the
# generated symbols are  Java_foundation_engine_mobile_Mobile_*  — ABI-mandated,
# must not be renamed by R8.
-keep class foundation.engine.** { *; }

# ── Flutter embedding ─────────────────────────────────────────────────────────
# FlutterEngine locates activities and plugins by their original class names
# via reflection.  Keep the entire embedding layer.
-keep class io.flutter.** { *; }

# ── Resource and config generated classes ───────────────────────────────────
# Under namespace="foundation.bridge" these are foundation.bridge.R and
# foundation.bridge.BuildConfig — already neutral, but kept explicitly.
-keep class **.R { *; }
-keep class **.R$* { *; }
-keep class **.BuildConfig { *; }

# ── Kotlin runtime ────────────────────────────────────────────────────────────
-keep class kotlin.Metadata { *; }
-keepclassmembernames class * {
    @kotlin.jvm.JvmStatic <methods>;
    @kotlin.jvm.JvmField <fields>;
}

# ── WorkManager (reflection-loaded workers) ──────────────────────────────────
-keep class * extends androidx.work.ListenableWorker { *; }

# ── Stripe (dontwarn carried forward from proguard-rules.pro) ────────────────
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
