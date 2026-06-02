/// Holds a deep link (confirm / friend invite) that arrived before the app
/// could act on it — typically because the user was still logged out. The
/// login flow replays it once the user is authenticated, so a shared invite /
/// confirm link opened from a cold, logged-out start is never lost.
///
/// Intentionally dependency-free (no navigator / Firebase imports) to avoid a
/// circular import with main.dart, which owns the actual navigation.
class PendingDeepLink {
  PendingDeepLink._();

  static String? route;
  static Object? args;

  static bool get isSet => route != null;

  static void stash(String r, Object? a) {
    route = r;
    args = a;
  }

  static void clear() {
    route = null;
    args = null;
  }
}
