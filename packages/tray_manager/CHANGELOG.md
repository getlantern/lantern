## 0.5.1

* Prevent plugin to be reregistered when spawning subwindow (#80)
* Fix the sandbox check to also work for docker/podman containers (#78)
* Fix: Resolved a memory leak when setting the icon multiple times on windows (#76)

## 0.5.0

* feat(windows): restore icon and context menu when Explorer restarts if necessary #71

## 0.4.0

* fix: resolve memory leak issue when update menu on macOS (#66)

## 0.3.1

* [macos] Support setting the icon size on macOS. (#60)

## 0.3.0

* chore: Add `bringAppToFront` param to `popUpContextMenu` method (#58)

## 0.2.4

* [windows][bug] fix the crash bug on windows targeting c++20 (#47)

## 0.2.3

* fix(macos): Fix app will crash when closing the tray. #44

## 0.2.2

* fix(linux): ensure icon works in sandboxed environments #43
* Updates minimum supported SDK version to Flutter 3.3/Dart 3.0.

## 0.2.1

* chore: Bump flutter to 3.6
* [linux] Fix libayatana set icon deprecation

## 0.2.0

* [macos] Implemented ` setIconPosition` method. (#25)

## 0.1.8

* [windows] getBounds method returns null when not initialized
* [macos] fixed destroy() not properly destroying tray icons #21 #22
* [macos] Fix getBounds crash

## 0.1.7

* [macos] Optimize tray icon click event response

## 0.1.6

* Support Flutter 3.0
* [macos] Implemented `setTitle` method.
* [linux] Implemented `setTitle` method. #15
* [linux] Fix build on Ubuntu 22.04 #16 #17

## 0.1.5

* Support Checkbox MenuItem #3
* [macos] Fixed onTrayIconMouseDown not triggered

## 0.1.4

* [macos] Fix the problem that the tray highlight state is incorrect #4 #10

## 0.1.3

* [windows] Implemented `setToolTip` Method.

## 0.1.2

* [macos] Add `isTemplate` parameter to `setIcon` method

## 0.1.1

* [linux] Remove `<uuid/uuid.h>` dependency

## 0.1.0

* Support sub menu.

## 0.0.2

* Implemented `destroy` Method.
* Implemented `setIcon` Method.
* Implemented `setContextMenu` Method.
* Implemented `popUpContextMenu` Method.
* Implemented `getBounds` Method.

## 0.0.1

* Initial release.
