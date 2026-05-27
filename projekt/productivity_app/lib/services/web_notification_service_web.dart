// Web-only implementation backed by the browser's Notifications API
// via dart:js_interop. Falls back to no-op when the API is missing
// (e.g. ancient browser, file://) so the page never crashes.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'web_notification_service.dart' show WebNotifPermission;

@JS('Notification')
external _NotificationConstructor? get _ctor;

extension type _NotificationConstructor._(JSObject _) implements JSObject {
  external String get permission;
  external JSPromise<JSString> requestPermission();
}

extension type _NotificationInstance._(JSObject _) implements JSObject {
  external set onclick(JSFunction f);
  external void close();
}

@JS('Notification')
external _NotificationInstance _newNotification(
    String title, JSObject? options);

@JS('window.focus')
external void _windowFocus();

WebNotifPermission _parse(String? p) {
  switch (p) {
    case 'granted':
      return WebNotifPermission.granted;
    case 'denied':
      return WebNotifPermission.denied;
    case 'default':
      return WebNotifPermission.defaultState;
    default:
      return WebNotifPermission.unsupported;
  }
}

WebNotifPermission readPermission() {
  final c = _ctor;
  if (c == null) return WebNotifPermission.unsupported;
  return _parse(c.permission);
}

Future<WebNotifPermission> requestPermission() async {
  final c = _ctor;
  if (c == null) return WebNotifPermission.unsupported;
  final result = await c.requestPermission().toDart;
  return _parse(result.toDart);
}

void showNotification({
  required String title,
  String? body,
  String? tag,
  VoidCallback? onClick,
}) {
  final c = _ctor;
  if (c == null || c.permission != 'granted') return;

  // Build options as a plain JS object using a literal.
  final options = _buildOptions(body: body, tag: tag);
  try {
    final n = _newNotification(title, options);
    if (onClick != null) {
      n.onclick = ((JSAny? _) {
        try {
          _windowFocus();
        } catch (_) {/* not available in every embedding */}
        onClick();
      }).toJS;
    }
  } catch (_) {/* surface as silent — Web Notifications shouldn't crash UI */}
}

JSObject _buildOptions({String? body, String? tag}) {
  final obj = JSObject();
  if (body != null) obj.setProperty('body'.toJS, body.toJS);
  if (tag != null) obj.setProperty('tag'.toJS, tag.toJS);
  obj.setProperty('icon'.toJS, '/icons/Icon-192.png'.toJS);
  return obj;
}
