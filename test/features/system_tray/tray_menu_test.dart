import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/system_tray/tray_menu.dart';
import 'package:tray_manager/tray_manager.dart' as tray;

class _FakeMenu implements tray.Menu {
  final rows = <Object?>[];
  var layouts = 0;
  var disposed = false;

  @override
  void clear() {
    rows.clear();
    layouts++;
  }

  @override
  void addItem(tray.MenuItem? item) => rows.add(item);

  @override
  void addSeparator() => rows.add(null);

  @override
  void dispose() => disposed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeItem implements tray.MenuItem {
  _FakeItem(this._label, this.type);

  String? _label;
  @override
  final tray.MenuItemType type;
  final sets = <String>[];
  FutureOr<void> Function(tray.MenuEvent)? _listener;
  var disposed = false;
  tray.Image? _icon;
  tray.Menu? _submenu;
  var _enabled = true;
  var _state = tray.MenuItemState.unchecked;

  @override
  String? get label => _label;
  @override
  set label(String? value) {
    sets.add('label');
    _label = value;
  }

  @override
  bool get isEnabled => _enabled;
  @override
  set isEnabled(bool value) {
    sets.add('enabled');
    _enabled = value;
  }

  @override
  tray.MenuItemState get state => _state;
  @override
  set state(tray.MenuItemState value) {
    sets.add('state');
    _state = value;
  }

  @override
  tray.Image? get icon => _icon;
  @override
  set icon(tray.Image? value) {
    sets.add('icon');
    _icon = value;
  }

  @override
  tray.Menu? get submenu => _submenu;
  @override
  set submenu(tray.Menu? value) {
    sets.add('submenu');
    _submenu = value;
  }

  @override
  int addListener(FutureOr<void> Function(tray.MenuEvent) callback) {
    _listener = callback;
    return 1;
  }

  void click() => _listener!(const tray.MenuItemClickedEvent(itemId: 1));

  @override
  void dispose() => disposed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeImage implements tray.Image {
  _FakeImage(this.asset);

  final String asset;
  var disposed = false;

  @override
  void dispose() => disposed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<_FakeMenu> menus;
  late List<_FakeItem> items;
  late List<_FakeImage> images;
  late TrayMenu menu;

  setUp(() {
    menus = [];
    items = [];
    images = [];
    menu = TrayMenu(
      createMenu: () {
        final menu = _FakeMenu();
        menus.add(menu);
        return menu;
      },
      createItem: (label, type) {
        final item = _FakeItem(label, type);
        items.add(item);
        return item;
      },
      loadImage: (asset) {
        final image = _FakeImage(asset);
        images.add(image);
        return image;
      },
    );
  });

  _FakeMenu root() => menus.first;
  List<String?> labels(_FakeMenu menu) => [
    for (final row in menu.rows) (row as _FakeItem?)?.label,
  ];

  test('changes to a row are made on its existing item', () {
    menu.update([
      TrayItem(key: 'toggle', label: 'Connect'),
      const TrayItem.separator(),
      TrayItem.checkbox(key: 'smart', label: 'Smart', checked: false),
    ]);
    final created = List.of(items);

    menu.update([
      TrayItem(key: 'toggle', label: 'Disconnect', disabled: true),
      const TrayItem.separator(),
      TrayItem.checkbox(key: 'smart', label: 'Smart', checked: true),
    ]);

    expect(items, created);
    expect(root().layouts, 1);
    expect(labels(root()), ['Disconnect', null, 'Smart']);
    expect(items[0].sets, ['label', 'enabled']);
    expect(items[0].isEnabled, isFalse);
    expect(items[1].sets, ['state']);
    expect(items[1].state, tray.MenuItemState.checked);
  });

  test('a row that comes and goes is added and freed', () {
    menu.update([
      TrayItem(key: 'status', label: 'Off'),
      TrayItem(key: 'blocked', label: 'Unable to connect'),
      TrayItem(key: 'quit', label: 'Quit'),
    ]);
    final [status, blocked, quit] = List.of(items);

    menu.update([
      TrayItem(key: 'status', label: 'Off'),
      TrayItem(key: 'quit', label: 'Quit'),
    ]);

    expect(root().rows, [status, quit]);
    expect(blocked.disposed, isTrue);
    expect(status.disposed || quit.disposed, isFalse);
    expect(items, hasLength(3));
  });

  test('submenus keep their menu and items', () {
    List<TrayItem> rows(String city) => [
      TrayItem.submenu(
        key: 'locations',
        label: 'Locations',
        submenu: [
          TrayItem(key: 'fr', label: city, icon: 'flags/fr.png'),
          TrayItem(key: 'de', label: 'Berlin', icon: 'flags/de.png'),
        ],
      ),
    ];

    menu.update(rows('Paris'));
    menu.update(rows('Lyon'));

    expect(menus, hasLength(2));
    expect(items, hasLength(3));
    expect(labels(menus[1]), ['Lyon', 'Berlin']);
    expect([for (final i in images) i.asset], ['flags/fr.png', 'flags/de.png']);
    expect(items[1].sets, ['icon', 'label']);
  });

  test('a click runs the handler of the latest update', () {
    final clicks = <String>[];
    menu.update([
      TrayItem(key: 'toggle', label: 'Connect', onClick: () => clicks.add('a')),
    ]);
    menu.update([
      TrayItem(key: 'toggle', label: 'Connect', onClick: () => clicks.add('b')),
    ]);

    items.single.click();

    expect(clicks, ['b']);
  });

  test('a row that changes type gets a new item', () {
    menu.update([TrayItem(key: 'smart', label: 'Smart')]);
    menu.update([
      TrayItem.checkbox(key: 'smart', label: 'Smart', checked: true),
    ]);

    expect(items, hasLength(2));
    expect(items.first.disposed, isTrue);
    expect(root().rows, [items.last]);
    expect(items.last.state, tray.MenuItemState.checked);
  });

  test('dispose frees every menu, item and image', () {
    menu.update([
      TrayItem.submenu(
        key: 'locations',
        label: 'Locations',
        submenu: [TrayItem(key: 'fr', label: 'Paris', icon: 'flags/fr.png')],
      ),
    ]);

    menu.dispose();

    expect(menus.every((m) => m.disposed), isTrue);
    expect(items.every((i) => i.disposed), isTrue);
    expect(images.single.disposed, isTrue);
  });
}
