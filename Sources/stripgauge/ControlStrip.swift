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

    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation"

    private static let setPresence: SetPresence? = {
        guard let handle = dlopen(frameworkPath, RTLD_NOW),
              let symbol = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier")
        else { return nil }
        return unsafeBitCast(symbol, to: SetPresence.self)
    }()

    private static let addSystemTrayItem = NSSelectorFromString("addSystemTrayItem:")

    /// False when a macOS update has moved or removed either private entry point.
    static var isAvailable: Bool {
        setPresence != nil && (NSTouchBarItem.self as AnyObject).responds(to: addSystemTrayItem)
    }

    static func register(_ item: NSTouchBarItem) {
        _ = (NSTouchBarItem.self as AnyObject).perform(addSystemTrayItem, with: item)
    }

    static func setVisible(_ visible: Bool, identifier: NSTouchBarItem.Identifier) {
        setPresence?(identifier.rawValue as NSString, visible)
    }
}
