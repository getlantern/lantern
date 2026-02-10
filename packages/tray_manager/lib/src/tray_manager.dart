import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:menu_base/menu_base.dart';
import 'package:path/path.dart' as path;
import 'package:shortid/shortid.dart';
import 'package:tray_manager/src/helpers/sandbox.dart';
import 'package:tray_manager/src/tray_listener.dart';

const kEventOnTrayIconMouseDown = 'onTrayIconMouseDown';
const kEventOnTrayIconMouseUp = 'onTrayIconMouseUp';
const kEventOnTrayIconRightMouseDown = 'onTrayIconRightMouseDown';
const kEventOnTrayIconRightMouseUp = 'onTrayIconRightMouseUp';
const kEventOnTrayMenuItemClick = 'onTrayMenuItemClick';

enum TrayIconPosition { left, right }

class TrayManager {
  TrayManager._() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  /// The shared instance of [TrayManager].
  static final TrayManager instance = TrayManager._();

  final MethodChannel _channel = const MethodChannel('tray_manager');

  final ObserverList<TrayListener> _listeners = ObserverList<TrayListener>();

  double get _devicePixelRatio {
    final flutterView = WidgetsBinding.instance.platformDispatcher.views.single;
    return MediaQueryData.fromView(flutterView).devicePixelRatio;
  }

  Menu? _menu;

  Future<void> _methodCallHandler(MethodCall call) async {
    for (final TrayListener listener in _listeners) {
      switch (call.method) {
        case kEventOnTrayIconMouseDown:
          listener.onTrayIconMouseDown();
          break;
        case kEventOnTrayIconMouseUp:
          listener.onTrayIconMouseUp();
          break;
        case kEventOnTrayIconRightMouseDown:
          listener.onTrayIconRightMouseDown();
          break;
        case kEventOnTrayIconRightMouseUp:
          listener.onTrayIconRightMouseUp();
          break;
        case kEventOnTrayMenuItemClick:
          int id = call.arguments['id'];
          MenuItem? menuItem = _menu?.getMenuItemById(id);
          if (menuItem != null) {
            bool? oldChecked = menuItem.checked;
            if (menuItem.onClick != null) {
              menuItem.onClick?.call(menuItem);
            }
            listener.onTrayMenuItemClick(menuItem);

            bool? newChecked = menuItem.checked;
            if (oldChecked != newChecked) {
              await setContextMenu(_menu!);
            }
          }
          break;
      }
    }
  }

  /// Whether any listeners are currently registered.
  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  /// Register a closure to be called when the tray events.
  void addListener(TrayListener listener) {
    _listeners.add(listener);
  }

  /// Remove a previously registered closure from the list of closures that are
  /// notified when the tray events.
  void removeListener(TrayListener listener) {
    _listeners.remove(listener);
  }

  // Destroys the tray icon immediately.
  Future<void> destroy() async {
    await _channel.invokeMethod('destroy');
  }

  /// Sets the image associated with this tray icon.
  ///
  /// [iconPath] is the path to the image file.
  ///
  /// However, if the app is running in a sandbox like Flatpak or Snap,
  /// [iconPath] should be the name of the icon as specified in the app's
  /// manifest file, without the path or file extension. For example, if the
  /// icon is specified as `org.example.app` in the Flatpak manifest file, then
  /// the icon should be passed as `org.example.app`.
  Future<void> setIcon(
    String iconPath, {
    bool isTemplate = false, // macOS only
    TrayIconPosition iconPosition = TrayIconPosition.left, // macOS only
    int iconSize = 18, // macOS only
  }) async {
    final Map<String, dynamic> arguments = {
      'id': shortid.generate(),
      'iconPath': path.joinAll([
        path.dirname(Platform.resolvedExecutable),
        'data/flutter_assets',
        iconPath,
      ]),
      'isTemplate': isTemplate,
      'iconPosition': iconPosition.name,
      'iconSize': iconSize,
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.linux:
        if (runningInSandbox()) {
          // Pass the icon name as specified if running in a sandbox.
          //
          // This is required because when running in a sandbox, paths are not
          // the same as seen by the app and the host system.
          arguments['iconPath'] = iconPath;
        }
        break;
      case TargetPlatform.macOS:
        // Add the icon as base64 string
        ByteData imageData = await rootBundle.load(iconPath);
        String base64Icon = base64Encode(imageData.buffer.asUint8List());
        arguments['base64Icon'] = base64Icon;
        break;
      default:
        break;
    }

    await _channel.invokeMethod('setIcon', arguments);
  }

  /// Sets the icon position of the tray icon.
  ///
  /// @platforms macos
  Future<void> setIconPosition(TrayIconPosition trayIconPosition) async {
    final arguments = <String, dynamic>{
      'iconPosition': trayIconPosition.name,
    };
    await _channel.invokeMethod('setIconPosition', arguments);
  }

  /// Sets the hover text for this tray icon.
  ///
  /// Must be called after the icon is set.
  /// ```dart
  /// await trayManager.setIcon(...);
  /// await trayManager.setToolTip(...);
  /// ```
  Future<void> setToolTip(String toolTip) async {
    final Map<String, dynamic> arguments = {
      'toolTip': toolTip,
    };
    await _channel.invokeMethod('setToolTip', arguments);
  }

  /// Sets the title for this tray icon.
  Future<void> setTitle(String title) async {
    final Map<String, dynamic> arguments = {
      'title': title,
    };
    await _channel.invokeMethod('setTitle', arguments);
  }

  /// Recursively processes menu item JSON, loading icon assets and
  /// replacing icon paths with base64-encoded image data.
  Future<void> _processMenuItemIcons(Map<String, dynamic> menuJson) async {
    final items = menuJson['items'] as List<dynamic>?;
    if (items == null) return;

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;

      // Process icon if present
      final iconPath = item['icon'];
      if (iconPath is String && iconPath.isNotEmpty) {
        try {
          final imageData = await rootBundle.load(iconPath);
          item['icon'] = base64Encode(imageData.buffer.asUint8List());
        } catch (e) {
          debugPrint('tray_manager: Failed to load icon "$iconPath": $e');
          item.remove('icon');
        }
      }

      // Recurse into submenus
      final submenu = item['submenu'];
      if (submenu is Map<String, dynamic>) {
        await _processMenuItemIcons(submenu);
      }
    }
  }

  /// Sets the context menu for this icon.
  Future<void> setContextMenu(Menu menu) async {
    _menu = menu;
    final menuJson = menu.toJson();
    await _processMenuItemIcons(menuJson);
    final Map<String, dynamic> arguments = {
      'menu': menuJson,
    };
    await _channel.invokeMethod('setContextMenu', arguments);
  }

  /// Pops up the context menu of the tray icon.
  ///
  /// [bringAppToFront] If true, the app will be brought to the front when the
  /// context menu is shown. Only works on Windows.
  Future<void> popUpContextMenu({
    @Deprecated(
      'This parameter is only supported on Windows and will be removed in the future.',
    )
    bool bringAppToFront = false,
  }) async {
    final Map<String, dynamic> arguments = {
      'bringAppToFront': bringAppToFront,
    };
    await _channel.invokeMethod('popUpContextMenu', arguments);
  }

  /// The bounds of this tray icon.
  Future<Rect?> getBounds() async {
    final Map<String, dynamic> arguments = {
      'devicePixelRatio': _devicePixelRatio,
    };
    final Map<dynamic, dynamic>? resultData = await _channel.invokeMethod(
      'getBounds',
      arguments,
    );
    if (resultData == null) {
      return null;
    }
    return Rect.fromLTWH(
      resultData['x'],
      resultData['y'],
      resultData['width'],
      resultData['height'],
    );
  }
}

final trayManager = TrayManager.instance;
