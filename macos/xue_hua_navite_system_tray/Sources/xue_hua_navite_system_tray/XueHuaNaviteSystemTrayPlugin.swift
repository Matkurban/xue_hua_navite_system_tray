import Cocoa
import FlutterMacOS
import UserNotifications

/// Native macOS implementation of the `xue_hua_navite_system_tray` plugin.
///
/// Uses AppKit's `NSStatusBar` and `NSStatusItem` for menu bar integration,
/// `NSMenu` and `NSMenuItem` for context menus, `NSApplication` activation policies
/// for Dock icon control, and `UNUserNotificationCenter` for notifications.
public class XueHuaNaviteSystemTrayPlugin: NSObject, FlutterPlugin, NSMenuDelegate {
  private let channel: FlutterMethodChannel
  private weak var registrar: FlutterPluginRegistrar?

  private var statusItem: NSStatusItem?
  private var contextMenu: NSMenu?
  private var menuTrigger: String = "rightClick"
  private var imagePosition: String = "leading"
  private var isTrayVisible: Bool = true

  /// Maps menu item IDs to their live `NSMenuItem` instances for fast in-place updates.
  private var menuItemMap: [String: NSMenuItem] = [:]

  /// Stores raw metadata for each menu item ID (type, groupId, checked state).
  private var menuItemMeta: [String: [String: Any]] = [:]

  public init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar? = nil) {
    self.channel = channel
    self.registrar = registrar
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "xue_hua_navite_system_tray",
      binaryMessenger: registrar.messenger
    )
    let instance = XueHuaNaviteSystemTrayPlugin(channel: channel, registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "initSystemTray":
      initSystemTray(args: args, result: result)
    case "setIcon":
      setIcon(args: args, result: result)
    case "setTitle":
      setTitle(args: args, result: result)
    case "setToolTip":
      setToolTip(args: args, result: result)
    case "setMenuTrigger":
      setMenuTrigger(args: args, result: result)
    case "setVisible":
      setVisible(args: args, result: result)
    case "setContextMenu":
      setContextMenu(args: args, result: result)
    case "updateMenuItem":
      updateMenuItem(args: args, result: result)
    case "popUpContextMenu":
      popUpContextMenu(result: result)
    case "getBounds":
      getBounds(result: result)
    case "showNotification":
      showNotification(args: args, result: result)
    case "setDockIconVisible":
      setDockIconVisible(args: args, result: result)
    case "showMainWindow":
      showMainWindow(args: args, result: result)
    case "hideMainWindow":
      hideMainWindow(result: result)
    case "isMainWindowVisible":
      isMainWindowVisible(result: result)
    case "getCapabilities":
      getCapabilities(result: result)
    case "destroy":
      destroyTray(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - System Tray Lifecycle

  private func ensureStatusItem() -> NSStatusItem {
    if let existing = statusItem {
      return existing
    }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      button.target = self
      button.action = #selector(handleStatusBarButtonClick(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp, .otherMouseUp])
    }
    statusItem = item
    return item
  }

  private func initSystemTray(args: [String: Any], result: @escaping FlutterResult) {
    let item = ensureStatusItem()

    if let trigger = args["menuTrigger"] as? String {
      menuTrigger = trigger
    }
    if let pos = args["imagePosition"] as? String {
      imagePosition = pos
    }

    if let iconMap = args["icon"] as? [String: Any] {
      applyIcon(to: item, iconMap: iconMap)
    }

    if let title = args["title"] as? String {
      item.button?.title = title
    } else {
      item.button?.title = ""
    }

    applyImagePosition(to: item)

    if let toolTip = args["toolTip"] as? String {
      item.button?.toolTip = toolTip.isEmpty ? nil : toolTip
    }

    if let visible = args["visible"] as? Bool {
      isTrayVisible = visible
      item.isVisible = visible
    }

    if let rawItems = args["menuItems"] as? [[String: Any]] {
      rebuildContextMenu(from: rawItems)
    }

    result(true)
  }

  private func setIcon(args: [String: Any], result: @escaping FlutterResult) {
    let item = ensureStatusItem()
    applyIcon(to: item, iconMap: args)
    applyImagePosition(to: item)
    result(nil)
  }

  private func setTitle(args: [String: Any], result: @escaping FlutterResult) {
    let item = ensureStatusItem()
    let title = args["title"] as? String ?? ""
    item.button?.title = title
    applyImagePosition(to: item)
    result(nil)
  }

  private func setToolTip(args: [String: Any], result: @escaping FlutterResult) {
    let item = ensureStatusItem()
    let toolTip = args["toolTip"] as? String ?? ""
    item.button?.toolTip = toolTip.isEmpty ? nil : toolTip
    result(nil)
  }

  private func setMenuTrigger(args: [String: Any], result: @escaping FlutterResult) {
    if let trigger = args["menuTrigger"] as? String {
      menuTrigger = trigger
    }
    if let pos = args["imagePosition"] as? String {
      imagePosition = pos
      if let item = statusItem {
        applyImagePosition(to: item)
      }
    }
    result(nil)
  }

  private func setVisible(args: [String: Any], result: @escaping FlutterResult) {
    let visible = args["visible"] as? Bool ?? true
    isTrayVisible = visible
    statusItem?.isVisible = visible
    result(nil)
  }

  private func destroyTray(result: @escaping FlutterResult) {
    if let item = statusItem {
      NSStatusBar.system.removeStatusItem(item)
      statusItem = nil
    }
    contextMenu = nil
    menuItemMap.removeAll()
    menuItemMeta.removeAll()
    result(nil)
  }

  // MARK: - Icon & Button Formatting

  private func applyImagePosition(to item: NSStatusItem) {
    guard let button = item.button else { return }
    let hasImage = button.image != nil
    let hasTitle = !button.title.isEmpty

    switch imagePosition {
    case "trailing":
      button.imagePosition = hasImage && hasTitle ? .imageTrailing : (hasImage ? .imageOnly : .noImage)
    case "onlyImage":
      button.imagePosition = .imageOnly
    case "onlyTitle":
      button.imagePosition = .noImage
    default:
      button.imagePosition = hasImage && hasTitle ? .imageLeading : (hasImage ? .imageOnly : .noImage)
    }
  }

  private func applyIcon(to item: NSStatusItem, iconMap: [String: Any]) {
    let defaultSize = iconMap["iconSize"] as? Double ?? 18.0
    if let image = loadNSImage(from: iconMap, defaultSize: defaultSize) {
      item.button?.image = image
    }
  }

  private func loadNSImage(from iconMap: [String: Any], defaultSize: Double) -> NSImage? {
    let type = iconMap["type"] as? String ?? "asset"
    let isTemplate = iconMap["isTemplate"] as? Bool ?? false
    let targetSize = CGFloat(iconMap["iconSize"] as? Double ?? defaultSize)

    var loadedImage: NSImage?

    switch type {
    case "asset":
      if let assetPath = iconMap["path"] as? String,
         let resolvedPath = resolveFlutterAssetPath(assetPath) {
        loadedImage = NSImage(contentsOfFile: resolvedPath)
      }
    case "file":
      if let filePath = iconMap["path"] as? String {
        loadedImage = NSImage(contentsOfFile: filePath)
      }
    case "bytes":
      if let typedData = iconMap["bytes"] as? FlutterStandardTypedData {
        loadedImage = NSImage(data: typedData.data)
      }
    case "system":
      if let symbolName = iconMap["systemName"] as? String {
        if #available(macOS 11.0, *) {
          let config = NSImage.SymbolConfiguration(pointSize: targetSize - 2, weight: .regular)
          loadedImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        }
        if loadedImage == nil {
          loadedImage = NSImage(named: symbolName)
        }
      }
    default:
      break
    }

    guard let image = loadedImage else { return nil }
    image.size = NSSize(width: targetSize, height: targetSize)
    image.isTemplate = isTemplate
    return image
  }

  private func resolveFlutterAssetPath(_ assetPath: String) -> String? {
    let mainBundlePath = Bundle.main.bundlePath
    let candidates = [
      "\(mainBundlePath)/Contents/Frameworks/App.framework/Resources/flutter_assets/\(assetPath)",
      "\(mainBundlePath)/Contents/Resources/flutter_assets/\(assetPath)",
      assetPath
    ]
    for candidate in candidates {
      if FileManager.default.fileExists(atPath: candidate) {
        return candidate
      }
    }
    return nil
  }

  // MARK: - Context Menu Construction & In-Place Updates

  private func setContextMenu(args: [String: Any], result: @escaping FlutterResult) {
    let rawItems = args["menuItems"] as? [[String: Any]] ?? []
    rebuildContextMenu(from: rawItems)
    result(nil)
  }

  private func rebuildContextMenu(from rawItems: [[String: Any]]) {
    menuItemMap.removeAll()
    menuItemMeta.removeAll()
    let menu = buildNSMenu(from: rawItems)
    menu.delegate = self
    contextMenu = menu
  }

  private func buildNSMenu(from items: [[String: Any]]) -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false

    for itemData in items {
      let type = itemData["type"] as? String ?? "action"
      let id = itemData["id"] as? String ?? UUID().uuidString

      if type == "separator" {
        menu.addItem(NSMenuItem.separator())
        continue
      }

      let label = itemData["label"] as? String ?? ""

      if type == "header" {
        let headerItem: NSMenuItem
        if #available(macOS 14.0, *) {
          headerItem = NSMenuItem.sectionHeader(title: label)
        } else {
          headerItem = NSMenuItem(title: label, action: nil, keyEquivalent: "")
          headerItem.isEnabled = false
          let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
          ]
          headerItem.attributedTitle = NSAttributedString(string: label, attributes: attributes)
        }
        menuItemMap[id] = headerItem
        menuItemMeta[id] = itemData
        menu.addItem(headerItem)
        continue
      }

      let nsItem = NSMenuItem(title: label, action: nil, keyEquivalent: "")
      nsItem.representedObject = id
      nsItem.isEnabled = itemData["enabled"] as? Bool ?? true

      if let toolTip = itemData["toolTip"] as? String, !toolTip.isEmpty {
        nsItem.toolTip = toolTip
      }

      if let iconMap = itemData["icon"] as? [String: Any],
         let iconImage = loadNSImage(from: iconMap, defaultSize: 16.0) {
        nsItem.image = iconImage
      }

      if let shortcutMap = itemData["shortcut"] as? [String: Any] {
        applyShortcut(shortcutMap, to: nsItem)
      }

      if type == "checkbox" || type == "radio" {
        let checked = itemData["checked"] as? Bool ?? false
        nsItem.state = checked ? .on : .off
      }

      if type == "submenu" {
        let childrenData = itemData["children"] as? [[String: Any]] ?? []
        let subMenu = buildNSMenu(from: childrenData)
        nsItem.submenu = subMenu
      } else {
        nsItem.target = self
        nsItem.action = #selector(handleMenuItemSelected(_:))
      }

      menuItemMap[id] = nsItem
      menuItemMeta[id] = itemData
      menu.addItem(nsItem)
    }

    return menu
  }

  private func applyShortcut(_ shortcutMap: [String: Any], to item: NSMenuItem) {
    let key = (shortcutMap["key"] as? String ?? "").lowercased()
    guard !key.isEmpty else { return }
    item.keyEquivalent = key

    var modifiers: NSEvent.ModifierFlags = []
    if shortcutMap["meta"] as? Bool == true {
      modifiers.insert(.command)
    }
    if shortcutMap["control"] as? Bool == true {
      modifiers.insert(.control)
    }
    if shortcutMap["alt"] as? Bool == true {
      modifiers.insert(.option)
    }
    if shortcutMap["shift"] as? Bool == true {
      modifiers.insert(.shift)
    }
    item.keyEquivalentModifierMask = modifiers
  }

  private func updateMenuItem(args: [String: Any], result: @escaping FlutterResult) {
    guard let id = args["id"] as? String,
          let item = menuItemMap[id] else {
      result(nil)
      return
    }

    if let label = args["label"] as? String {
      item.title = label
    }
    if let toolTip = args["toolTip"] as? String {
      item.toolTip = toolTip.isEmpty ? nil : toolTip
    }
    if let enabled = args["enabled"] as? Bool {
      item.isEnabled = enabled
    }
    if let checked = args["checked"] as? Bool {
      item.state = checked ? .on : .off
      menuItemMeta[id]?["checked"] = checked
    }
    if let iconMap = args["icon"] as? [String: Any],
       let image = loadNSImage(from: iconMap, defaultSize: 16.0) {
      item.image = image
    }

    result(nil)
  }

  @objc private func handleMenuItemSelected(_ sender: NSMenuItem) {
    guard let id = sender.representedObject as? String else { return }
    var meta = menuItemMeta[id] ?? [:]
    let type = meta["type"] as? String ?? "action"
    var updatedChecked: Bool? = nil

    if type == "checkbox" {
      let current = sender.state == .on
      let nextState = !current
      sender.state = nextState ? .on : .off
      meta["checked"] = nextState
      menuItemMeta[id] = meta
      updatedChecked = nextState
    } else if type == "radio" {
      let groupId = meta["groupId"] as? String
      if let group = groupId, !group.isEmpty {
        for (otherId, otherMeta) in menuItemMeta {
          if (otherMeta["type"] as? String) == "radio" &&
             (otherMeta["groupId"] as? String) == group {
            let isSelected = (otherId == id)
            menuItemMap[otherId]?.state = isSelected ? .on : .off
            menuItemMeta[otherId]?["checked"] = isSelected
          }
        }
      } else {
        sender.state = .on
        meta["checked"] = true
        menuItemMeta[id] = meta
      }
      updatedChecked = true
    }

    var payload: [String: Any] = [
      "type": "menuItemClick",
      "mouseButton": "left",
      "menuItemId": id,
      "timestamp": Int(Date().timeIntervalSince1970 * 1000)
    ]
    if let checked = updatedChecked {
      payload["checked"] = checked
    }
    if let bounds = computeStatusItemBounds() {
      payload["bounds"] = bounds
    }
    channel.invokeMethod("onTrayEvent", arguments: payload)
  }

  // MARK: - Mouse Click Handling & Menu Popup

  @objc private func handleStatusBarButtonClick(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else {
      emitTrayClickEvent(type: "leftClick", mouseButton: "left")
      return
    }

    let isDouble = event.clickCount >= 2

    switch event.type {
    case .rightMouseUp, .rightMouseDown:
      let eventType = isDouble ? "rightDoubleClick" : "rightClick"
      emitTrayClickEvent(type: eventType, mouseButton: "right")
      if menuTrigger == "rightClick" || menuTrigger == "anyClick" {
        showContextMenuOnStatusItem()
      }
    case .otherMouseUp, .otherMouseDown:
      emitTrayClickEvent(type: "middleClick", mouseButton: "middle")
    default:
      let eventType = isDouble ? "leftDoubleClick" : "leftClick"
      emitTrayClickEvent(type: eventType, mouseButton: "left")
      if menuTrigger == "leftClick" || menuTrigger == "anyClick" {
        showContextMenuOnStatusItem()
      }
    }
  }

  private func popUpContextMenu(result: @escaping FlutterResult) {
    showContextMenuOnStatusItem()
    result(nil)
  }

  private func showContextMenuOnStatusItem() {
    guard let item = statusItem,
          let menu = contextMenu,
          let button = item.button else { return }

    item.menu = menu
    button.performClick(nil)
    item.menu = nil
  }

  private func emitTrayClickEvent(type: String, mouseButton: String) {
    let mouseLoc = NSEvent.mouseLocation
    let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
    let flippedCursorY = primaryScreenHeight > 0 ? (primaryScreenHeight - mouseLoc.y) : mouseLoc.y

    var payload: [String: Any] = [
      "type": type,
      "mouseButton": mouseButton,
      "cursorX": Double(mouseLoc.x),
      "cursorY": Double(flippedCursorY),
      "timestamp": Int(Date().timeIntervalSince1970 * 1000)
    ]
    if let bounds = computeStatusItemBounds() {
      payload["bounds"] = bounds
    }
    channel.invokeMethod("onTrayEvent", arguments: payload)
  }

  private func computeStatusItemBounds() -> [String: Double]? {
    guard let button = statusItem?.button,
          let window = button.window else {
      return nil
    }
    let rectInWindow = button.convert(button.bounds, to: nil)
    let screenRect = window.convertToScreen(rectInWindow)
    let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
    let topY = primaryScreenHeight > 0
      ? (primaryScreenHeight - screenRect.origin.y - screenRect.size.height)
      : screenRect.origin.y

    return [
      "x": Double(screenRect.origin.x),
      "y": Double(topY),
      "width": Double(screenRect.size.width),
      "height": Double(screenRect.size.height)
    ]
  }

  private func getBounds(result: @escaping FlutterResult) {
    result(computeStatusItemBounds())
  }

  // MARK: - Notifications

  private func showNotification(args: [String: Any], result: @escaping FlutterResult) {
    let title = args["title"] as? String ?? ""
    let message = args["message"] as? String ?? ""
    let playSound = args["playSound"] as? Bool ?? true

    guard Bundle.main.bundleIdentifier != nil else {
      result(false)
      return
    }

    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = message
      if playSound {
        content.sound = .default
      }
      let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
      )
      center.add(request) { error in
        DispatchQueue.main.async {
          result(error == nil && granted)
        }
      }
    }
  }

  // MARK: - Window & Dock Management

  private func setDockIconVisible(args: [String: Any], result: @escaping FlutterResult) {
    let visible = args["visible"] as? Bool ?? true
    let policy: NSApplication.ActivationPolicy = visible ? .regular : .accessory
    NSApp.setActivationPolicy(policy)
    if visible {
      NSApp.activate(ignoringOtherApps: true)
    }
    result(nil)
  }

  private func mainAppWindow() -> NSWindow? {
    if let viewWindow = registrar?.view?.window {
      return viewWindow
    }
    return NSApp.windows.first { window in
      let className = NSStringFromClass(type(of: window))
      return !className.contains("NSStatusBar") && !className.contains("NSPopup")
    }
  }

  private func showMainWindow(args: [String: Any], result: @escaping FlutterResult) {
    let focus = args["focus"] as? Bool ?? true
    if let window = mainAppWindow() {
      if window.isMiniaturized {
        window.deminiaturize(nil)
      }
      window.makeKeyAndOrderFront(nil)
      if focus {
        NSApp.activate(ignoringOtherApps: true)
      }
    }
    result(nil)
  }

  private func hideMainWindow(result: @escaping FlutterResult) {
    mainAppWindow()?.orderOut(nil)
    result(nil)
  }

  private func isMainWindowVisible(result: @escaping FlutterResult) {
    guard let window = mainAppWindow() else {
      result(false)
      return
    }
    result(window.isVisible && !window.isMiniaturized)
  }

  // MARK: - Capabilities

  private func getCapabilities(result: @escaping FlutterResult) {
    result([
      "platform": "macos",
      "backendName": "NSStatusItem",
      "supportsInlineTitle": true,
      "supportsTemplateIcon": true,
      "supportsSystemSymbol": true,
      "supportsIconBounds": true,
      "supportsLeftRightClickDistinction": true,
      "supportsDoubleClick": true,
      "supportsMiddleClick": true,
      "supportsMenuIcons": true,
      "supportsMenuShortcuts": true,
      "supportsMenuTooltips": true,
      "supportsProgrammaticMenuPopup": true,
      "supportsDockVisibilityToggle": true,
      "supportsTrayNotification": true
    ])
  }
}
