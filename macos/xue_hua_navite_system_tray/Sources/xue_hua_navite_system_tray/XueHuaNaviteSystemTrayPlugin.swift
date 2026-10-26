import Cocoa
import FlutterMacOS
import ObjectiveC.runtime
import UserNotifications

/// Native macOS implementation of the `xue_hua_navite_system_tray` plugin.
///
/// Uses AppKit's `NSStatusBar` and `NSStatusItem` for menu bar integration,
/// `NSMenu` and `NSMenuItem` for context menus, `NSApplication` activation policies
/// for Dock icon control, and `UNUserNotificationCenter` for notifications.
public class XueHuaNaviteSystemTrayPlugin: NSObject, FlutterPlugin, NSMenuDelegate {
    private let channel: FlutterMethodChannel

    /// Strongly retained registrar so `registrar?.view?.window` and asset lookup
    /// remain valid throughout the application lifecycle.
    private var registrar: FlutterPluginRegistrar?

    /// Cached weak reference to the primary Flutter `NSWindow` so it can still be
    /// located and restored after `window.orderOut(nil)` hides it.
    private weak var cachedMainWindow: NSWindow?

    /// Tracks whether the system tray is active or the main window was hidden to
    /// the tray, preventing `applicationShouldTerminateAfterLastWindowClosed`
    /// from unexpectedly quitting the app when `hideMainWindow()` is called.
    private static var shouldPreventAppTerminationOnWindowHide: Bool = false
    private static var didInstallAppDelegateTerminationGuard: Bool = false

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
        DispatchQueue.main.async { [weak self] in
            _ = self?.mainAppWindow()
            Self.installAppDelegateTerminationGuardIfNeeded()
        }
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
        let args = asDictionary(call.arguments) ?? [:]

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
            popUpContextMenu(args: args, result: result)
        case "dismissContextMenu":
            dismissContextMenu(result: result)
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

    // MARK: - Safe Objective-C / Swift Collection Bridging

    private func asDictionary(_ value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] {
            return dict
        }
        if let nsDict = value as? NSDictionary {
            var result: [String: Any] = [:]
            for (key, val) in nsDict {
                if let keyStr = key as? String, !(val is NSNull) {
                    result[keyStr] = val
                }
            }
            return result
        }
        return nil
    }

    private func asDictionaryArray(_ value: Any?) -> [[String: Any]] {
        if let array = value as? [[String: Any]] {
            return array
        }
        if let nsArray = value as? NSArray {
            return nsArray.compactMap { asDictionary($0) }
        }
        return []
    }

    private func asBool(_ value: Any?, default defaultValue: Bool) -> Bool {
        if let b = value as? Bool {
            return b
        }
        if let num = value as? NSNumber {
            return num.boolValue
        }
        return defaultValue
    }

    private func asDouble(_ value: Any?, default defaultValue: Double) -> Double {
        if let d = value as? Double {
            return d
        }
        if let num = value as? NSNumber {
            return num.doubleValue
        }
        return defaultValue
    }

    // MARK: - AppDelegate Termination Guard for Minimize-to-Tray

    /// Installs a runtime guard on `NSApp.delegate` so that ordering out the last
    /// window via `hideMainWindow()` does not trigger AppKit's
    /// `applicationShouldTerminateAfterLastWindowClosed` auto-exit behavior.
    private static func installAppDelegateTerminationGuardIfNeeded() {
        guard !didInstallAppDelegateTerminationGuard,
              let delegate = NSApp.delegate else { return }

        let delegateClass: AnyClass = object_getClass(delegate)!
        let originalSelector = #selector(NSApplicationDelegate.applicationShouldTerminateAfterLastWindowClosed(_:))
        let swizzledSelector = #selector(XueHuaNaviteSystemTrayPlugin.xueHua_applicationShouldTerminateAfterLastWindowClosed(_:))

        guard let swizzledMethod = class_getInstanceMethod(
            XueHuaNaviteSystemTrayPlugin.self,
            swizzledSelector
        ) else { return }

        if let originalMethod = class_getInstanceMethod(delegateClass, originalSelector) {
            let didAdd = class_addMethod(
                delegateClass,
                swizzledSelector,
                method_getImplementation(swizzledMethod),
                method_getTypeEncoding(swizzledMethod)
            )
            if didAdd, let newSwizzledMethod = class_getInstanceMethod(delegateClass, swizzledSelector) {
                method_exchangeImplementations(originalMethod, newSwizzledMethod)
            }
        } else {
            class_addMethod(
                delegateClass,
                originalSelector,
                method_getImplementation(swizzledMethod),
                method_getTypeEncoding(swizzledMethod)
            )
        }

        didInstallAppDelegateTerminationGuard = true
    }

    @objc private func xueHua_applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        if XueHuaNaviteSystemTrayPlugin.shouldPreventAppTerminationOnWindowHide {
            return false
        }
        if responds(to: #selector(XueHuaNaviteSystemTrayPlugin.xueHua_applicationShouldTerminateAfterLastWindowClosed(_:))) {
            return xueHua_applicationShouldTerminateAfterLastWindowClosed(sender)
        }
        return false
    }

    // MARK: - System Tray Lifecycle

    private func ensureStatusItem() -> NSStatusItem {
        Self.installAppDelegateTerminationGuardIfNeeded()
        Self.shouldPreventAppTerminationOnWindowHide = true
        _ = mainAppWindow()

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

        if let iconMap = asDictionary(args["icon"]) {
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

        let visible = asBool(args["visible"], default: true)
        isTrayVisible = visible
        item.isVisible = visible

        let rawItems = asDictionaryArray(args["menuItems"])
        if !rawItems.isEmpty || args["menuItems"] != nil {
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
        let visible = asBool(args["visible"], default: true)
        isTrayVisible = visible
        statusItem?.isVisible = visible
        result(nil)
    }

    private func destroyTray(result: @escaping FlutterResult) {
        Self.shouldPreventAppTerminationOnWindowHide = false
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
        let defaultSize = asDouble(iconMap["iconSize"], default: 18.0)
        if let image = loadNSImage(from: iconMap, defaultSize: defaultSize) {
            item.button?.image = image
        }
    }

    /// Loads an `NSImage` from a serialized `TrayIconSource` dictionary.
    ///
    /// - For `system` SF Symbols: Applies `NSImage.SymbolConfiguration` directly
    ///   without overwriting `.size` so AppKit preserves the vector symbol's
    ///   aspect ratio and rendering metadata.
    /// - For `asset`, `file`, and `bytes` bitmap images: Sets `.size` to
    ///   `NSSize(width: targetSize, height: targetSize)` and `.isTemplate = isTemplate`.
    private func loadNSImage(from iconMap: [String: Any], defaultSize: Double) -> NSImage? {
        let type = iconMap["type"] as? String ?? "asset"
        let isTemplate = asBool(iconMap["isTemplate"], default: false)
        let targetSize = CGFloat(asDouble(iconMap["iconSize"], default: defaultSize))

        switch type {
        case "system":
            guard let symbolName = iconMap["systemName"] as? String, !symbolName.isEmpty else {
                return nil
            }
            if #available(macOS 11.0, *), let symbol = resolveSystemSymbolImage(named: symbolName) {
                let config = NSImage.SymbolConfiguration(
                    pointSize: max(13.0, targetSize - 2.0),
                    weight: .regular
                )
                let configured = symbol.withSymbolConfiguration(config) ?? symbol
                configured.isTemplate = isTemplate
                return configured
            }
            if let namedImg = NSImage(named: symbolName)?.copy() as? NSImage {
                namedImg.size = NSSize(width: targetSize, height: targetSize)
                namedImg.isTemplate = isTemplate
                return namedImg
            }
            return nil

        case "asset":
            if let assetPath = iconMap["path"] as? String,
               let resolvedPath = resolveFlutterAssetPath(assetPath),
               let image = NSImage(contentsOfFile: resolvedPath)
            {
                image.size = NSSize(width: targetSize, height: targetSize)
                image.isTemplate = isTemplate
                return image
            }
            return nil

        case "file":
            if let filePath = iconMap["path"] as? String,
               let image = NSImage(contentsOfFile: filePath)
            {
                image.size = NSSize(width: targetSize, height: targetSize)
                image.isTemplate = isTemplate
                return image
            }
            return nil

        case "bytes":
            var rawData: Data?
            if let typedData = iconMap["bytes"] as? FlutterStandardTypedData {
                rawData = typedData.data
            } else if let data = iconMap["bytes"] as? Data {
                rawData = data
            }
            if let data = rawData, let image = NSImage(data: data) {
                image.size = NSSize(width: targetSize, height: targetSize)
                image.isTemplate = isTemplate
                return image
            }
            return nil

        default:
            return nil
        }
    }

    @available(macOS 11.0, *)
    private func resolveSystemSymbolImage(named symbolName: String) -> NSImage? {
        if let direct = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            return direct
        }
        let fallbacks: [String: [String]] = [
            "arrow.triangle.2.circlepath": ["arrow.clockwise", "arrow.2.circlepath"],
            "macwindow": ["window.ceiling", "uiwindow.split.2x1", "rectangle"],
            "speedometer": ["gauge", "dial.medium", "slider.horizontal.3"],
            "eye.slash": ["eye", "minus.square"],
            "bell": ["bell.fill", "exclamationmark.bubble"],
            "trash": ["xmark.circle", "minus.circle"],
        ]
        if let candidates = fallbacks[symbolName] {
            for candidate in candidates {
                if let img = NSImage(systemSymbolName: candidate, accessibilityDescription: nil) {
                    return img
                }
            }
        }
        return nil
    }

    private func resolveFlutterAssetPath(_ assetPath: String) -> String? {
        let mainBundlePath = Bundle.main.bundlePath
        var candidates: [String] = []

        if let registrar = registrar {
            let lookupKey = registrar.lookupKey(forAsset: assetPath)
            if let bundlePath = Bundle.main.path(forResource: lookupKey, ofType: nil) {
                candidates.append(bundlePath)
            }
            candidates.append("\(mainBundlePath)/Contents/\(lookupKey)")
            candidates.append("\(mainBundlePath)/Contents/Frameworks/App.framework/Resources/\(lookupKey)")
        }

        candidates.append(contentsOf: [
            "\(mainBundlePath)/Contents/Frameworks/App.framework/Resources/flutter_assets/\(assetPath)",
            "\(mainBundlePath)/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/\(assetPath)",
            "\(mainBundlePath)/Contents/Resources/flutter_assets/\(assetPath)",
            assetPath,
        ])

        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Context Menu Construction & In-Place Updates

    /// Ensures that a menu item's image is explicitly visible on macOS 26 / macOS 27+.
    ///
    /// Starting with applications linked against the macOS 26 / macOS 27 SDK
    /// (`macosx27.0`), AppKit's `NSMenu` hides `NSMenuItem.image` (both SF Symbols
    /// and bitmap/asset images) by default when `preferredImageVisibility` is left
    /// at `.automatic`. Setting `preferredImageVisibility = .visible` (raw value `1`)
    /// restores explicit icon rendering for every menu item configured with an icon.
    private func ensureMenuItemImageVisible(_ item: NSMenuItem) {
        #if compiler(>=6.3)
            if #available(macOS 27.0, *) {
                item.preferredImageVisibility = .visible
                return
            }
        #endif
        let selector = NSSelectorFromString("setPreferredImageVisibility:")
        if item.responds(to: selector) {
            item.setValue(1, forKey: "preferredImageVisibility")
        }
    }

    private func setContextMenu(args: [String: Any], result: @escaping FlutterResult) {
        let rawItems = asDictionaryArray(args["menuItems"])
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
        menu.showsStateColumn = true

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
                        .font: NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize),
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
            nsItem.isEnabled = asBool(itemData["enabled"], default: true)

            if let toolTip = itemData["toolTip"] as? String, !toolTip.isEmpty {
                nsItem.toolTip = toolTip
            }

            if let iconMap = asDictionary(itemData["icon"]),
               let iconImage = loadNSImage(from: iconMap, defaultSize: 16.0)
            {
                nsItem.image = iconImage
                ensureMenuItemImageVisible(nsItem)
            }

            if let shortcutMap = asDictionary(itemData["shortcut"]) {
                applyShortcut(shortcutMap, to: nsItem)
            }

            if type == "checkbox" || type == "radio" {
                let checked = asBool(itemData["checked"], default: false)
                nsItem.state = checked ? .on : .off
            }

            if type == "submenu" {
                let childrenData = asDictionaryArray(itemData["children"])
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
        if asBool(shortcutMap["meta"], default: false) {
            modifiers.insert(.command)
        }
        if asBool(shortcutMap["control"], default: false) {
            modifiers.insert(.control)
        }
        if asBool(shortcutMap["alt"], default: false) {
            modifiers.insert(.option)
        }
        if asBool(shortcutMap["shift"], default: false) {
            modifiers.insert(.shift)
        }
        item.keyEquivalentModifierMask = modifiers
    }

    private func updateMenuItem(args: [String: Any], result: @escaping FlutterResult) {
        guard let id = args["id"] as? String,
              let item = menuItemMap[id]
        else {
            result(nil)
            return
        }

        if let label = args["label"] as? String {
            item.title = label
        }
        if let toolTip = args["toolTip"] as? String {
            item.toolTip = toolTip.isEmpty ? nil : toolTip
        }
        if args["enabled"] != nil {
            item.isEnabled = asBool(args["enabled"], default: item.isEnabled)
        }
        if args["checked"] != nil {
            let checked = asBool(args["checked"], default: item.state == .on)
            item.state = checked ? .on : .off
            menuItemMeta[id]?["checked"] = checked
        }
        if let iconMap = asDictionary(args["icon"]),
           let image = loadNSImage(from: iconMap, defaultSize: 16.0)
        {
            item.image = image
            ensureMenuItemImageVisible(item)
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
                    if (otherMeta["type"] as? String) == "radio",
                       (otherMeta["groupId"] as? String) == group
                    {
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
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
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

    @objc private func handleStatusBarButtonClick(_: NSStatusBarButton) {
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

    private func popUpContextMenu(args: [String: Any], result: @escaping FlutterResult) {
        // Reply first (Windows parity) so method-channel / flutter_driver
        // requestData cannot stall while the status-item menu is open.
        let autoDismissMs = asDouble(args["autoDismissMs"], default: 0)
        result(nil)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Schedule cancel before performClick so the timer can fire inside
            // AppKit's nested menu-tracking run loop.
            if autoDismissMs > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissMs / 1000.0) { [weak self] in
                    self?.contextMenu?.cancelTracking()
                    self?.statusItem?.menu = nil
                }
            }
            self.showContextMenuOnStatusItem()
        }
    }

    private func dismissContextMenu(result: @escaping FlutterResult) {
        contextMenu?.cancelTracking()
        statusItem?.menu = nil
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
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ]
        if let bounds = computeStatusItemBounds() {
            payload["bounds"] = bounds
        }
        channel.invokeMethod("onTrayEvent", arguments: payload)
    }

    private func computeStatusItemBounds() -> [String: Double]? {
        guard let button = statusItem?.button,
              let window = button.window
        else {
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
            "height": Double(screenRect.size.height),
        ]
    }

    private func getBounds(result: @escaping FlutterResult) {
        result(computeStatusItemBounds())
    }

    // MARK: - Notifications

    private func showNotification(args: [String: Any], result: @escaping FlutterResult) {
        let title = args["title"] as? String ?? ""
        let message = args["message"] as? String ?? ""
        let playSound = asBool(args["playSound"], default: true)

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
        let visible = asBool(args["visible"], default: true)
        Self.installAppDelegateTerminationGuardIfNeeded()
        Self.shouldPreventAppTerminationOnWindowHide = true

        DispatchQueue.main.async {
            let policy: NSApplication.ActivationPolicy = visible ? .regular : .accessory
            NSApp.setActivationPolicy(policy)
            if visible {
                NSApp.activate(ignoringOtherApps: true)
            }
            result(nil)
        }
    }

    /// Resolves and caches the primary Flutter `NSWindow`, carefully excluding
    /// internal AppKit status bar, menu, and popup windows.
    private func mainAppWindow() -> NSWindow? {
        if let cached = cachedMainWindow {
            return cached
        }
        if let viewWindow = registrar?.view?.window {
            viewWindow.isReleasedWhenClosed = false
            cachedMainWindow = viewWindow
            return viewWindow
        }
        if let flutterWindow = NSApp.windows.first(where: { window in
            if window.contentViewController is FlutterViewController {
                return true
            }
            let className = NSStringFromClass(type(of: window))
            return className.contains("MainFlutterWindow") || className.contains("FlutterWindow")
        }) {
            flutterWindow.isReleasedWhenClosed = false
            cachedMainWindow = flutterWindow
            return flutterWindow
        }
        if let normalWindow = NSApp.windows.first(where: { window in
            let className = NSStringFromClass(type(of: window))
            let isSystemPopup = className.contains("NSStatusBar")
                || className.contains("NSPopup")
                || className.contains("NSMenu")
                || className.contains("NSCarbon")
                || className.contains("TUINS")
            return !isSystemPopup && window.canBecomeMain
        }) {
            normalWindow.isReleasedWhenClosed = false
            cachedMainWindow = normalWindow
            return normalWindow
        }
        return nil
    }

    private func showMainWindow(args: [String: Any], result: @escaping FlutterResult) {
        let focus = asBool(args["focus"], default: true)
        DispatchQueue.main.async { [weak self] in
            if let window = self?.mainAppWindow() {
                window.isReleasedWhenClosed = false
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                if focus {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            result(nil)
        }
    }

    private func hideMainWindow(result: @escaping FlutterResult) {
        Self.installAppDelegateTerminationGuardIfNeeded()
        Self.shouldPreventAppTerminationOnWindowHide = true

        DispatchQueue.main.async { [weak self] in
            if let window = self?.mainAppWindow() {
                window.isReleasedWhenClosed = false
                window.orderOut(nil)
            }
            result(nil)
        }
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
            "supportsTrayNotification": true,
        ])
    }
}
