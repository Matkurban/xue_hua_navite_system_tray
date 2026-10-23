import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/models/tray_capabilities.dart';
import 'src/models/tray_config.dart';
import 'src/models/tray_event.dart';
import 'src/models/tray_icon_source.dart';
import 'src/models/tray_menu_item.dart';
import 'src/models/tray_notification.dart';
import 'xue_hua_navite_system_tray_platform_interface.dart';

/// An implementation of [XueHuaNaviteSystemTrayPlatform] that uses a [MethodChannel].
class MethodChannelXueHuaNaviteSystemTray
    extends XueHuaNaviteSystemTrayPlatform {
  /// Constructs a [MethodChannelXueHuaNaviteSystemTray] and attaches the native
  /// callback handler.
  MethodChannelXueHuaNaviteSystemTray() {
    methodChannel.setMethodCallHandler(_handleNativeMethodCall);
  }

  /// The method channel used to interact with the native desktop platform.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'xue_hua_navite_system_tray',
  );

  final StreamController<TrayEvent> _eventController =
      StreamController<TrayEvent>.broadcast();

  final Map<String, TrayMenuItem> _registeredMenuItems =
      <String, TrayMenuItem>{};

  @override
  Stream<TrayEvent> get events => _eventController.stream;

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onTrayEvent' && call.arguments is Map) {
      final Map<dynamic, dynamic> raw = call.arguments as Map<dynamic, dynamic>;
      final TrayEvent event = TrayEvent.fromMap(raw);
      if (event.type == TrayEventType.menuItemClick &&
          event.menuItemId != null) {
        final TrayMenuItem? item = _registeredMenuItems[event.menuItemId!];
        if (item != null) {
          // Defer callbacks so hideMainWindow/showMainWindow (and other channel
          // invokes) are never nested inside this inbound onTrayEvent handler.
          // Nested platform-channel calls have caused process teardown on
          // Windows when Minimize-to-Tray runs from a tray menu item.
          final TrayMenuItem captured = item;
          final bool? checked = event.checked;
          scheduleMicrotask(() {
            if (captured.type == TrayMenuItemType.checkbox) {
              captured.onChanged?.call(checked ?? !captured.checked);
            } else {
              captured.onTap?.call();
            }
          });
        }
      }
      _eventController.add(event);
    }
  }

  void _indexMenuItems(List<TrayMenuItem> items) {
    for (final TrayMenuItem item in items) {
      _registeredMenuItems[item.id] = item;
      if (item.children.isNotEmpty) {
        _indexMenuItems(item.children);
      }
    }
  }

  @override
  Future<bool> initSystemTray(TrayConfig config) async {
    _registeredMenuItems.clear();
    _indexMenuItems(config.menuItems);
    final bool? result = await methodChannel.invokeMethod<bool>(
      'initSystemTray',
      config.toMap(),
    );
    return result ?? false;
  }

  @override
  Future<void> setIcon(TrayIconSource icon) async {
    await methodChannel.invokeMethod<void>('setIcon', icon.toMap());
  }

  @override
  Future<void> setTitle(String? title) async {
    await methodChannel.invokeMethod<void>('setTitle', <String, dynamic>{
      'title': title ?? '',
    });
  }

  @override
  Future<void> setToolTip(String? toolTip) async {
    await methodChannel.invokeMethod<void>('setToolTip', <String, dynamic>{
      'toolTip': toolTip ?? '',
    });
  }

  @override
  Future<void> setMenuTrigger(
    TrayMenuTrigger trigger, {
    TrayImagePosition? imagePosition,
  }) async {
    await methodChannel.invokeMethod<void>('setMenuTrigger', <String, dynamic>{
      'menuTrigger': trigger.name,
      if (imagePosition != null) 'imagePosition': imagePosition.name,
    });
  }

  @override
  Future<void> setVisible(bool visible) async {
    await methodChannel.invokeMethod<void>('setVisible', <String, dynamic>{
      'visible': visible,
    });
  }

  @override
  Future<void> setContextMenu(List<TrayMenuItem> items) async {
    _registeredMenuItems.clear();
    _indexMenuItems(items);
    await methodChannel.invokeMethod<void>('setContextMenu', <String, dynamic>{
      'menuItems': items.map((TrayMenuItem item) => item.toMap()).toList(),
    });
  }

  @override
  Future<void> updateMenuItem(
    String id, {
    String? label,
    String? toolTip,
    bool? enabled,
    bool? checked,
    TrayIconSource? icon,
  }) async {
    await methodChannel.invokeMethod<void>('updateMenuItem', <String, dynamic>{
      'id': id,
      'label': ?label,
      'toolTip': ?toolTip,
      'enabled': ?enabled,
      'checked': ?checked,
      if (icon != null) 'icon': icon.toMap(),
    });
  }

  @override
  Future<void> popUpContextMenu() async {
    await methodChannel.invokeMethod<void>('popUpContextMenu');
  }

  @override
  Future<TrayBounds?> getBounds() async {
    final Map<dynamic, dynamic>? raw = await methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('getBounds');
    if (raw == null) {
      return null;
    }
    return TrayBounds.fromMap(raw);
  }

  @override
  Future<bool> showNotification(TrayNotification notification) async {
    final bool? shown = await methodChannel.invokeMethod<bool>(
      'showNotification',
      notification.toMap(),
    );
    return shown ?? false;
  }

  @override
  Future<void> setDockIconVisible(bool visible) async {
    await methodChannel.invokeMethod<void>(
      'setDockIconVisible',
      <String, dynamic>{'visible': visible},
    );
  }

  @override
  Future<void> showMainWindow({bool focus = true}) async {
    await methodChannel.invokeMethod<void>('showMainWindow', <String, dynamic>{
      'focus': focus,
    });
  }

  @override
  Future<void> hideMainWindow() async {
    await methodChannel.invokeMethod<void>('hideMainWindow');
  }

  @override
  Future<bool> isMainWindowVisible() async {
    final bool? visible = await methodChannel.invokeMethod<bool>(
      'isMainWindowVisible',
    );
    return visible ?? true;
  }

  @override
  Future<TrayCapabilities> getCapabilities() async {
    final Map<dynamic, dynamic>? raw = await methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('getCapabilities');
    return TrayCapabilities.fromMap(raw ?? <String, dynamic>{});
  }

  @override
  Future<void> destroy() async {
    _registeredMenuItems.clear();
    await methodChannel.invokeMethod<void>('destroy');
  }
}
