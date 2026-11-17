# AppAuth Android 0.11.1 logs expected/returned OAuth state on mismatch.
# Strip only its logging entry points in minified release builds. Reinspect on upgrade.
-assumenosideeffects class net.openid.appauth.internal.Logger {
    public static void verbose(...);
    public static void verboseWithStack(...);
    public static void debug(...);
    public static void debugWithStack(...);
    public static void info(...);
    public static void infoWithStack(...);
    public static void warn(...);
    public static void warnWithStack(...);
    public static void error(...);
    public static void errorWithStack(...);
}
