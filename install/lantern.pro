-ignorewarnings

-include ../Lantern.pro

-keep public class org.lantern.Launcher {
     public static void main(java.lang.String[]);
}

-keep public class org.apache.log4j.** {
    public protected *;
}

-keep public class org.apache.commons.logging.** {
    public protected *;
}

-keep class dbusjava_localized,
            dbusjava_localized_en_GB

-keep class org.freedesktop.** {
    *;
}

-keep class cx.ath.matthew.** {
    *;
}

-keep class org.jivesoftware.**

-keep class fr.free.miniupnp.** {
    <fields>;
    <methods>;
}

-keepclassmembers class * {
   @com.google.common.eventbus.Subscribe *;
}

-keepclassmembers class org.lastbamboo.common.sdp.** {
   *;
}


-keep class com.sun.jna.** {
    *;
}

-keep class com.barchart.udt.** {
    *;
}

-keepclassmembers class * extends com.sun.jna.** {
    <fields>;
    <methods>;
}

-keep class sun.proxy.** {
    *;
}

#guice
-keep class com.google.inject.** { *; } 
-keep class javax.inject.** { *; } 
-keep class javax.annotation.** { *; } 

# enum gobbledygook
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep native things
-keepclasseswithmembernames class * {
    native <methods>;
}

# Use annotations to keep things
-keep @org.lantern.annotation.Keep class *

-keepclassmembers @org.lantern.annotation.Keep class * {
     *;
}

-keep class org.lantern.LanternModule {
    *;
}

-keepclassmembers class * { 
    @com.google.inject.Inject <init>(...) ; 
}

# Annotations
-keepattributes *Annotation*

# referenced by string
-keep class org.lantern.SettingsJSONContextServer {
    public protected *;
}

-keepclassmembers class org.lantern.** {
    *;
}

-dontobfuscate
-dontoptimize
-dontwarn sun.misc.Unsafe
-dontwarn com.google.common.collect.MinMaxPriorityQueue
-dontnote

#plain -dontwarn does not work, so this hack:
-dontwarn org.**
-dontwarn com.**
-dontwarn javax.**
-dontwarn java.**
-dontwarn javassist.**
-dontwarn gnu.**
