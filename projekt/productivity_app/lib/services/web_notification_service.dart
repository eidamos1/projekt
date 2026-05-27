// Web notifications via the browser's Notifications API. Foreground-only —
// when the tab is closed nothing fires (full push would require FCM +
// service worker + Cloud Functions; see docs/plans).
//
// Imports `dart:js_interop` lazily — outside the Flutter web build the
// stubs do nothing, so platform checks at call sites stay clean.

import 'package:flutter/foundation.dart';
import 'web_notification_service_stub.dart'
    if (dart.library.js_interop) 'web_notification_service_web.dart' as impl;

/// Permission state mirrors the browser's `Notification.permission` values.
enum WebNotifPermission { granted, denied, defaultState, unsupported }

class WebNotificationService {
  static WebNotificationService? _instance;
  factory WebNotificationService() => _instance ??= WebNotificationService._();
  WebNotificationService._();

  /// Current browser permission. Returns [WebNotifPermission.unsupported]
  /// on non-web platforms.
  WebNotifPermission get permission {
    if (!kIsWeb) return WebNotifPermission.unsupported;
    return impl.readPermission();
  }

  /// Triggers the browser permission prompt. No-op outside web. Returns
  /// the new permission state.
  Future<WebNotifPermission> requestPermission() async {
    if (!kIsWeb) return WebNotifPermission.unsupported;
    return impl.requestPermission();
  }

  /// Shows a notification. Silently skipped if permission isn't granted
  /// or if not running on web. [onClick] is invoked when the user clicks
  /// the notification (after the browser focuses the tab).
  void show({
    required String title,
    String? body,
    String? tag,
    VoidCallback? onClick,
  }) {
    if (!kIsWeb) return;
    if (permission != WebNotifPermission.granted) return;
    impl.showNotification(
      title: title,
      body: body,
      tag: tag,
      onClick: onClick,
    );
  }
}
