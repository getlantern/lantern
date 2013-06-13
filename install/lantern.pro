-injars ../target/lantern-0.3-SNAPSHOT-jar-with-dependencies.jar
-outjars ../target/lanternpro.jar

# XXX these paths are OS X only
-libraryjars <java.home>/../Classes/classes.jar
-libraryjars <java.home>/../Classes/jsse.jar
-libraryjars <java.home>/lib/jce.jar
-libraryjars <java.home>/lib/javaws.jar
-libraryjars <java.home>/lib/dt.jar
-ignorewarnings
-target 1.6

-keep public class org.lantern.Launcher {
     public static void main(java.lang.String[]);
}

-keep public class org.apache.log4j.** {
    public protected *;
}

-keep public class org.apache.commons.logging.** {
    public protected *;
}

# -keep class org.eclipse.swt.widgets.Display,
#             org.eclipse.swt.browser.** {
#     *;
# }


-keep class org.eclipse.swt.** {
    *;
}


# enum gobbledygook
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep native things
-keepclasseswithmembernames class * {
    native <methods>;
}

# Beanish things
-keep class org.lantern.Settings,
            org.lantern.Whitelist,
            org.lantern.WhitelistEntry,
            org.lantern.Internet, 
            org.lantern.ConnectivityStatus,
            org.lantern.SettingsState,
            org.lantern.Country,
            org.lantern.Platform, 
            org.lantern.httpseverywhere.* {
    *;
}

# Annotations
-keepattributes *Annotation*

# referenced by string
-keep class org.lantern.SettingsJSONContextServer {
    public proctected *;
}

-keep class org.jivesoftware.smack.sasl.** {
    public protected *;
}

-dontobfuscate
-dontoptimize

#-keeppackagenames org.apache.log4j.**


-verbose

