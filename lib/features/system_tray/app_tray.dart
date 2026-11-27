import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

/// One row of the tray menu. A null [label] is a separator.
class TrayEntry {
  const TrayEntry({
    required String this.label,
    this.enabled = true,
    this.checked,
    this.icon,
    this.onClick,
    this.children,
  });

  const TrayEntry.separator()
    : label = null,
      enabled = false,
      checked = null,
      icon = null,
      onClick = null,
      children = null;

  final String? label;
  final bool enabled;

  /// Non-null makes the row a checkbox.
  final bool? checked;

  /// An asset name or a file path.
  final String? icon;
  final void Function()? onClick;

  /// Non-null makes the row a submenu.
  final List<TrayEntry>? children;
}

/// The app's single tray icon and its menu.
class AppTray {
  AppTray._();

  static final AppTray instance = AppTray._();

  TrayIcon? _trayIcon;
  ListenerId? _listenerId;
  Image? _image;
  String? _imagePath;
  _NativeMenu? _menu;

  void Function()? onClick;
  void Function()? onRightClick;

  TrayIcon get _icon {
    var icon = _trayIcon;
    if (icon != null) return icon;
    icon = TrayIcon.create();
    if (icon == null) throw StateError('Unable to create the tray icon');
    _listenerId = icon.addListener((event) {
      switch (event) {
        case TrayIconClickedEvent():
          onClick?.call();
        case TrayIconRightClickedEvent():
          onRightClick?.call();
        default:
          break;
      }
    });
    icon.setVisible(true);
    return _trayIcon = icon;
  }

  /// Returns false when the image could not be loaded; the old icon stays.
  bool setIcon(String path, {bool isTemplate = false}) {
    if (path == _imagePath) return true;
    final image = ImageAsset.fromAsset(path) ?? Image.fromFile(path);
    if (image == null) return false;
    _icon
      ..isIconTemplate = isTemplate
      ..icon = image;
    _image?.dispose();
    _image = image;
    _imagePath = path;
    return true;
  }

  void setTooltip(String tooltip) => _icon.setTooltip(tooltip);

  void setMenu(List<TrayEntry> entries) {
    final menu = _NativeMenu(entries);
    _icon.setContextMenu(menu.root);
    // Linux panels only show a menu that has a trigger.
    if (Platform.isLinux) {
      _icon.setContextMenuTrigger(ContextMenuTrigger.rightClicked);
    }
    _disposeLater(_menu);
    _menu = menu;
  }

  void openMenu() => _icon.openContextMenu();

  void destroy() {
    final listenerId = _listenerId;
    if (listenerId != null) _trayIcon?.removeListener(listenerId);
    _listenerId = null;
    _disposeLater(_menu);
    _menu = null;
    _image?.dispose();
    _image = null;
    _imagePath = null;
    _trayIcon?.dispose();
    _trayIcon = null;
  }

  // A click handler may replace the menu its own item belongs to, so the old
  // menu has to outlive the native callback.
  void _disposeLater(_NativeMenu? menu) {
    if (menu != null) Timer.run(menu.dispose);
  }
}

/// A native menu and the handles that must stay alive with it.
class _NativeMenu {
  _NativeMenu(List<TrayEntry> entries) {
    root = _build(entries);
  }

  late final Menu root;
  final List<Menu> _menus = [];
  final List<Image> _icons = [];
  final List<(MenuItem, ListenerId)> _items = [];

  Menu _build(List<TrayEntry> entries) {
    final menu = Menu.create();
    if (menu == null) throw StateError('Unable to create the tray menu');
    _menus.add(menu);

    for (final entry in entries) {
      final label = entry.label;
      if (label == null) {
        menu.addSeparator();
        continue;
      }
      final children = entry.children;
      final checked = entry.checked;
      final type = children != null
          ? MenuItemType.submenu
          : checked != null
          ? MenuItemType.checkbox
          : MenuItemType.normal;
      final item = MenuItem.createWithLabelAndType(label, type);
      if (item == null) {
        throw StateError('Unable to create the tray menu item $label');
      }
      item.isEnabled = entry.enabled;
      final state = checked == true
          ? MenuItemState.checked
          : MenuItemState.unchecked;
      if (type == MenuItemType.checkbox) item.state = state;

      final iconPath = entry.icon;
      if (iconPath != null) {
        final icon = ImageAsset.fromAsset(iconPath) ?? Image.fromFile(iconPath);
        if (icon != null) {
          item.icon = icon;
          _icons.add(icon);
        }
      }
      if (children != null) item.submenu = _build(children);

      final listenerId = item.addListener((event) {
        if (event is! MenuItemClickedEvent) return;
        entry.onClick?.call();
        // Some platforms tick a checkbox on click; the state comes from the app.
        if (type == MenuItemType.checkbox) item.state = state;
      });
      _items.add((item, listenerId));
      menu.addItem(item);
    }
    return menu;
  }

  void dispose() {
    for (final (item, listenerId) in _items) {
      item.removeListener(listenerId);
      item.dispose();
    }
    _items.clear();
    for (final icon in _icons) {
      icon.dispose();
    }
    _icons.clear();
    for (final menu in _menus) {
      menu.dispose();
    }
    _menus.clear();
  }
}
