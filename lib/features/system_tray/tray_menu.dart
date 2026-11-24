import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart' as tray;

/// A row of the tray menu. Rows are matched to native items by [key], which
/// must be unique across the whole menu.
class TrayItem {
  const TrayItem({
    required String this.key,
    required this.label,
    this.disabled = false,
    this.icon,
    this.onClick,
  }) : checked = null,
       submenu = null;

  const TrayItem.checkbox({
    required String this.key,
    required this.label,
    required bool this.checked,
    this.disabled = false,
    this.onClick,
  }) : icon = null,
       submenu = null;

  const TrayItem.submenu({
    required String this.key,
    required this.label,
    required List<TrayItem> this.submenu,
    this.disabled = false,
  }) : checked = null,
       icon = null,
       onClick = null;

  const TrayItem.separator()
    : key = null,
      label = '',
      disabled = false,
      checked = null,
      icon = null,
      submenu = null,
      onClick = null;

  /// Null for a separator.
  final String? key;
  final String label;
  final bool disabled;

  /// Non-null for a checkbox.
  final bool? checked;

  /// An asset path.
  final String? icon;
  final List<TrayItem>? submenu;
  final VoidCallback? onClick;

  tray.MenuItemType get type => switch (this) {
    TrayItem(submenu: _?) => tray.MenuItemType.submenu,
    TrayItem(checked: _?) => tray.MenuItemType.checkbox,
    _ => tray.MenuItemType.normal,
  };
}

/// The tray's context menu. [update] reuses the native item for each key and
/// sends only what changed, so redrawing the menu on every state change
/// creates no native menus, and a click always lands on a live item.
class TrayMenu {
  TrayMenu({
    tray.Menu Function()? createMenu,
    tray.MenuItem Function(String label, tray.MenuItemType type)? createItem,
    tray.Image? Function(String asset)? loadImage,
  }) : _createMenu = createMenu ?? (() => tray.Menu.create()!),
       _createItem =
           createItem ??
           ((label, type) =>
               tray.MenuItem.createWithLabelAndType(label, type)!),
       _loadImage = loadImage ?? tray.ImageAsset.fromAsset {
    _root = _Menu(_createMenu());
  }

  final tray.Menu Function() _createMenu;
  final tray.MenuItem Function(String, tray.MenuItemType) _createItem;
  final tray.Image? Function(String) _loadImage;
  late final _Menu _root;
  final _items = <String, _Item>{};
  final _images = <String, tray.Image?>{};

  tray.Menu get menu => _root.menu;

  void update(List<TrayItem> items) {
    final seen = <String>{};
    _fill(_root, items, seen);
    _items.removeWhere((key, item) {
      if (seen.contains(key)) return false;
      item.dispose();
      return true;
    });
  }

  void dispose() {
    for (final item in _items.values) {
      item.dispose();
    }
    _items.clear();
    _root.menu.dispose();
    for (final image in _images.values) {
      image?.dispose();
    }
    _images.clear();
  }

  void _fill(_Menu menu, List<TrayItem> rows, Set<String> seen) {
    final items = [
      for (final row in rows) row.key == null ? null : _sync(row, seen),
    ];
    if (listEquals(items, menu.items)) return;
    menu.menu.clear();
    for (final item in items) {
      if (item == null) {
        menu.menu.addSeparator();
      } else {
        menu.menu.addItem(item.native);
      }
    }
    menu.items = items;
  }

  _Item _sync(TrayItem row, Set<String> seen) {
    final key = row.key!;
    assert(!seen.contains(key), 'Duplicate tray item key: $key');
    seen.add(key);
    var item = _items[key];
    if (item == null || item.type != row.type) {
      item?.dispose();
      item = _items[key] = _Item(_createItem(row.label, row.type), row.type);
    }
    final native = item.native;
    final old = item.row;
    if (old != null && old.label != row.label) native.label = row.label;
    if ((old?.disabled ?? false) != row.disabled) {
      native.isEnabled = !row.disabled;
    }
    if ((old?.checked ?? false) != (row.checked ?? false)) {
      native.state = row.checked!
          ? tray.MenuItemState.checked
          : tray.MenuItemState.unchecked;
    }
    if (old?.icon != row.icon) {
      final icon = row.icon;
      native.icon = icon == null
          ? null
          : _images.putIfAbsent(icon, () => _loadImage(icon));
    }
    if (row.submenu case final rows?) {
      final submenu = item.submenu ??= _Menu(_createMenu());
      if (old == null) native.submenu = submenu.menu;
      _fill(submenu, rows, seen);
    }
    item.row = row;
    return item;
  }
}

class _Menu {
  _Menu(this.menu);

  final tray.Menu menu;

  /// The items it holds, in order, with null for a separator.
  List<_Item?> items = const [];
}

class _Item {
  _Item(this.native, this.type) {
    native.addListener((event) {
      if (event is tray.MenuItemClickedEvent) row?.onClick?.call();
    });
  }

  final tray.MenuItem native;
  final tray.MenuItemType type;

  /// The row it shows now.
  TrayItem? row;
  _Menu? submenu;

  void dispose() {
    native.dispose();
    submenu?.menu.dispose();
  }
}
