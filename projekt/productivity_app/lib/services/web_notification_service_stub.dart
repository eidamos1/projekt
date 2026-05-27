// Stub implementation for non-web platforms (mobile, desktop, tests).
// All methods are no-ops so the public WebNotificationService API stays
// clean for callers that don't need to know the platform.

import 'package:flutter/foundation.dart';
import 'web_notification_service.dart' show WebNotifPermission;

WebNotifPermission readPermission() => WebNotifPermission.unsupported;

Future<WebNotifPermission> requestPermission() async =>
    WebNotifPermission.unsupported;

void showNotification({
  required String title,
  String? body,
  String? tag,
  VoidCallback? onClick,
}) {}
