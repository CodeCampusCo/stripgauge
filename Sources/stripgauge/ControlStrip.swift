import AppKit

/// The only place that touches private API.
///
/// Two things here are undocumented: the `DFRFoundation` function that decides
/// whether an item is present in the Control Strip, and `NSTouchBarItem`'s
/// `addSystemTrayItem:` class method. Reaching them through `dlsym` and a
/// selector — rather than linking the private framework and writing a bridging
/// header — is what keeps this package building with plain SwiftPM.
enum ControlStrip {
    private typealias SetPresence = @convention(c) (NSString, Bool) -> Void
    private typealias SetCloseBoxVisible = @convention(c) (Bool) -> Void

    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation"

    // A dlopen handle: opened once, never written again.
    nonisolated(unsafe) private static let framework = dlopen(frameworkPath, RTLD_NOW)

    private static let setPresence: SetPresence? = {
        guard let symbol = dlsym(framework, "DFRElementSetControlStripPresenceForIdentifier")
        else { return nil }
        return unsafeBitCast(symbol, to: SetPresence.self)
    }()

    private static let setCloseBoxVisible: SetCloseBoxVisible? = {
        guard let symbol = dlsym(framework, "DFRSystemModalShowsCloseBoxWhenFrontMost")
        else { return nil }
        return unsafeBitCast(symbol, to: SetCloseBoxVisible.self)
    }()

    private static let addSystemTrayItem = NSSelectorFromString("addSystemTrayItem:")
    private static let present =
        NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
    private static let minimize = NSSelectorFromString("minimizeSystemModalTouchBar:")

    /// False when a macOS update has moved or removed either private entry point.
    static var isAvailable: Bool {
        setPresence != nil && (NSTouchBarItem.self as AnyObject).responds(to: addSystemTrayItem)
    }

    /// Expanding is optional: if these entry points disappear, tapping simply
    /// does nothing and the gauge keeps working.
    static var canExpand: Bool {
        setCloseBoxVisible != nil
            && (NSTouchBar.self as AnyObject).responds(to: present)
            && (NSTouchBar.self as AnyObject).responds(to: minimize)
    }

    static func register(_ item: NSTouchBarItem) {
        _ = (NSTouchBarItem.self as AnyObject).perform(addSystemTrayItem, with: item)
    }

    static func setVisible(_ visible: Bool, identifier: NSTouchBarItem.Identifier) {
        setPresence?(identifier.rawValue as NSString, visible)
    }

    /// Covers the app-specific half of the Touch Bar. The Control Strip stays,
    /// so brightness and volume remain reachable while this is up.
    static func expand(_ touchBar: NSTouchBar, from identifier: NSTouchBarItem.Identifier) {
        guard canExpand else { return }
        setCloseBoxVisible?(true)
        _ = (NSTouchBar.self as AnyObject).perform(
            present, with: touchBar, with: identifier.rawValue as NSString)
    }

    static func collapse(_ touchBar: NSTouchBar) {
        guard canExpand else { return }
        _ = (NSTouchBar.self as AnyObject).perform(minimize, with: touchBar)
    }
}
