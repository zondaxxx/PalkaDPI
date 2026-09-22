# Keep JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}

-keep class io.github.romanvht.byedpi.core.ByeDpiProxy { *; }

-keep,allowoptimization class io.github.romanvht.byedpi.core.TProxyService { *; }
-keep,allowoptimization class io.github.romanvht.byedpi.activities.** { *; }
-keep,allowoptimization class io.github.romanvht.byedpi.services.** { *; }
-keep,allowoptimization class io.github.romanvht.byedpi.receiver.** { *; }

-keep class io.github.romanvht.byedpi.fragments.** {
    <init>();
}

-keep,allowoptimization class io.github.romanvht.byedpi.data.** {
    <fields>;
}

-keepattributes Signature
-keepattributes *Annotation*

-repackageclasses 'ru.romanvht'
-renamesourcefileattribute ''
-keepattributes SourceFile,InnerClasses,EnclosingMethod,Signature,RuntimeVisibleAnnotations,*Annotation*,*Parcelable*
-allowaccessmodification
-overloadaggressively
-optimizationpasses 5
-verbose
-dontusemixedcaseclassnames
-adaptclassstrings
-adaptresourcefilecontents **.xml,**.json
-adaptresourcefilenames **.xml,**.json
# net.i2p.crypto:eddsa references JDK-internal classes that do not exist on Android
-dontwarn sun.security.x509.**
-dontwarn sun.security.**
-keep class net.i2p.crypto.eddsa.** { *; }
# PalkaDPI models are (de)serialised with Gson by field name
-keep class io.github.romanvht.byedpi.palka.OnlineStrategy { *; }
-keep class io.github.romanvht.byedpi.palka.OnlineStrategyCatalog { *; }
-keep class io.github.romanvht.byedpi.palka.CatalogCacheEntry { *; }
-keep class io.github.romanvht.byedpi.palka.PalkaNetworkProfile { *; }
-keep class io.github.romanvht.byedpi.palka.PalkaNetworkKind { *; }
-keep class io.github.romanvht.byedpi.palka.PalkaStrategyStats { *; }
-keep class io.github.romanvht.byedpi.palka.PalkaRuntimeLogEntry { *; }
