## 1.0.7

* Windows: `popUpContextMenu` no longer blocks the method-channel Future — reply Success first, then show the menu via `PostMessage` (TrackPopupMenu is modal). Optional `autoDismissMs` / `dismissContextMenu` support automated tests.
* Example/tests: make flutter_driver and full-API IT cross-platform (Windows/Linux/macOS); fix workbench Row overflows; asset icon IT uses platform system icons.

## 1.0.6

* Linux: AppIndicator asset/file/bytes tray icons now register the icon directory via `app_indicator_set_icon_theme_path` and pass the basename, so custom icons actually resolve under Ayatana/AppIndicator.
* Linux: `popUpContextMenu` is a safe no-op on AppIndicator backends (matches `supportsProgrammaticMenuPopup: false`) and no longer triggers `gtk_menu_popup_at_rect` critical assertions.
* Example: added `flutter_driver` harness (`test_driver/`) plus fuller Linux integration coverage for icons, menu callbacks, window hide/show, destroy/reinit; example UI uses `ValueKey`s for lifecycle controls.

## 1.0.5

* Windows: fixed `hideMainWindow` process teardown when invoked from the tray menu by completing the method-channel reply before ShowWindow, validating the Flutter root HWND, and deferring menu onTap/onChanged off the inbound onTrayEvent handler (shared Dart fix also helps Linux).

## 1.0.4

* Windows: scale tray context-menu item icons to `SM_CXMENUCHECK` so asset/system glyphs match menu text height.

## 1.0.3

* Replaced explicit null checks in map literals with null-aware elements (`'key': ?value`) so `use_null_aware_elements` static analysis passes.

## 1.0.2

* Fixed Linux CMake / gtest build issues that blocked CMake 4.x builds.
* Hardened Linux system tray integration tests and `notify-send` capability detection.

## 1.0.1

* Fixed Windows CMake / gtest build issues that blocked Visual Studio 2026 builds.
* Hardened Windows system tray integration tests (init, menu, tooltip, bounds, notification, main window show/hide).

## 1.0.0

* Initial stable release of `xue_hua_navite_system_tray` by Matkurban (`3496354336@qq.com`).
