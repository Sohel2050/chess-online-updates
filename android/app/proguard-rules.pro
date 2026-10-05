# =====================================================================
# proguard-rules.pro  -  Unity LevelPlay + mediation networks
# Place at: android/app/proguard-rules.pro
# =====================================================================

-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepattributes SourceFile, LineNumberTable
-keepattributes JavascriptInterface

# ---------------- Flutter ----------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.play.core.**

# ---------------- WebView JS bridge (used by most ad SDKs) ----------------
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ---------------- Google Play Services (ads id, app set, basement) ----------------
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.appset.** { *; }
-keep class com.google.android.gms.ads.identifier.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**

# ---------------- Google Play Billing ----------------
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ---------------- Unity LevelPlay (ironSource) core ----------------
-keep class com.ironsource.** { *; }
-keep class com.ironsource.adapters.** { *; }
-keepclassmembers class com.ironsource.sdk.controller.IronSourceWebView$JSInterface {
    public *;
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
-keep public class com.google.android.gms.ads.** { public *; }
-keep class com.ironsource.unity.androidbridge.** { *; }
-keep class com.ironsource.ironsource_mediation.** { *; }
-keep class com.unity3d.mediation.** { *; }
-dontwarn com.ironsource.**
-dontwarn com.unity3d.mediation.**

# ---------------- IAB OMID (used by several networks) ----------------
-keep class com.iab.omid.library.** { *; }
-dontwarn com.iab.omid.library.**

# ---------------- AppLovin ----------------
-keep class com.applovin.** { *; }
-keep class com.applovin.mediation.adapters.** { *; }
-keep class com.applovin.mediation.adapter.** { *; }
-keep public class com.applovin.mediation.* { public protected *; }
-dontwarn com.applovin.**

# ---------------- Chartboost ----------------
-keep class com.chartboost.** { *; }
-dontwarn com.chartboost.**

# ---------------- Meta Audience Network ----------------
-keep class com.facebook.ads.** { *; }
-keep class com.facebook.ads.internal.** { *; }
-dontwarn com.facebook.ads.**

# ---------------- InMobi ----------------
-keep class com.inmobi.** { *; }
-dontwarn com.inmobi.**
-keep class com.squareup.picasso.** { *; }
-dontwarn com.squareup.picasso.**
-dontwarn com.squareup.okhttp.**
-dontwarn okio.**

# ---------------- Mintegral ----------------
-keep class com.mbridge.** { *; }
-keep interface com.mbridge.** { *; }
-keep class com.mbridge.msdk.foundation.** { *; }
-keep class **.R$* {
    public static final int mbridge*;
}
-dontwarn com.mbridge.**

# ---------------- MobileFuse ----------------
-keep class com.mobilefuse.** { *; }
-dontwarn com.mobilefuse.**

# ---------------- Moloco ----------------
-keep class com.moloco.** { *; }
-dontwarn com.moloco.**

# ---------------- Ogury ----------------
-keep class co.ogury.** { *; }
-dontwarn co.ogury.**

# ---------------- PubMatic OpenWrap ----------------
-keep class com.pubmatic.sdk.** { *; }
-dontwarn com.pubmatic.sdk.**

# ---------------- Smaato ----------------
-keep public class com.smaato.sdk.** { *; }
-keep public interface com.smaato.sdk.** { *; }
-dontwarn com.smaato.sdk.**

# ---------------- Unity Ads ----------------
-keep class com.unity3d.ads.** { *; }
-keep class com.unity3d.services.** { *; }
-dontwarn com.unity3d.ads.**
-dontwarn com.unity3d.services.**

# ---------------- Verve (HyBid / PubNative) ----------------
-keep class net.pubnative.** { *; }
-keep class net.pubnative.lite.sdk.** { *; }
-dontwarn net.pubnative.**

# ---------------- Yandex ----------------
-keep class com.yandex.mobile.ads.** { *; }
-dontwarn com.yandex.mobile.ads.**

# ---------------- Vungle (Liftoff Monetize) ----------------
-keep class com.vungle.** { *; }
-dontwarn com.vungle.**
-dontwarn retrofit2.Platform$Java8

# ---------------- Common transitive warnings ----------------
-dontwarn kotlin.**
-dontwarn kotlinx.**
-dontwarn org.jetbrains.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
