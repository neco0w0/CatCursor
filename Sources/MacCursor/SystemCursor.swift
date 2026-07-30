import Cocoa

// MARK: - CoreGraphics interop
//
// NSCursor.hide() and CGDisplayHideCursor() only affect the cursor while the
// calling process is frontmost. Opting the window-server connection into
// "SetsCursorInBackground" lifts that restriction, which is what lets an
// accessory app hide the pointer system-wide. Not public API, but it needs no
// entitlement, no TCC permission and no SIP changes.
//
// CGCursorIsVisible is public-but-deprecated and reports global visibility, so
// it doubles as the health check for "did something turn the pointer back on".

typealias CGSConnectionID = UInt32

@_silgen_name("CGSDefaultConnectionForThread")
private func CGSDefaultConnectionForThread() -> CGSConnectionID

@_silgen_name("CGSSetConnectionProperty")
private func CGSSetConnectionProperty(_ cid: CGSConnectionID,
                                      _ targetCID: CGSConnectionID,
                                      _ key: CFString,
                                      _ value: CFTypeRef) -> CGError

@_silgen_name("CGCursorIsVisible")
private func _CGCursorIsVisible() -> Int32

/// Owns the visibility of the real system pointer.
enum SystemCursor {
    private(set) static var isHiding = false

    /// Shared window-server connection, also used for reading the live cursor.
    static var connection: CGSConnectionID { CGSDefaultConnectionForThread() }

    static var isVisible: Bool { _CGCursorIsVisible() != 0 }

    /// Allow this process to control the cursor while it is in the background.
    /// Safe to call more than once.
    @discardableResult
    static func enableBackgroundControl() -> Bool {
        let cid = CGSDefaultConnectionForThread()
        return CGSSetConnectionProperty(cid, cid,
                                        "SetsCursorInBackground" as CFString,
                                        kCFBooleanTrue) == .success
    }

    static func hide() {
        guard !isHiding else { return }
        isHiding = CGDisplayHideCursor(CGMainDisplayID()) == .success
    }

    /// Brings the real pointer back, and verifies that it actually came back.
    ///
    /// CGDisplayHideCursor is reference counted, and `reassertIfNeeded` adds
    /// hides that are never individually paired with a show, so the count can
    /// sit above one. A single CGDisplayShowCursor would then decrement without
    /// revealing anything -- which would silently break the fallback that hands
    /// control back to the system cursor, the one path that must never fail.
    /// The first show is unconditional, and must stay that way.
    /// CGCursorIsVisible is deprecated and can still report "visible" moments
    /// after a hide, so gating the call on it turns restore() into a no-op and
    /// strands the user with no pointer at all. The loop only exists to undo any
    /// extra hides `reassertIfNeeded` stacked up.
    static func restore() {
        guard isHiding else { return }
        isHiding = false
        var attempts = 0
        repeat {
            CGDisplayShowCursor(CGMainDisplayID())
            attempts += 1
        } while !isVisible && attempts < 8
    }

    /// Space switches, display changes and waking from sleep can bring the real
    /// pointer back even though we never asked for it. Re-hiding is cheap, so
    /// the tracker calls this periodically rather than trying to catch every
    /// notification that might be responsible.
    static func reassertIfNeeded() {
        guard isHiding, isVisible else { return }
        CGDisplayHideCursor(CGMainDisplayID())
    }
}
