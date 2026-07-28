import Foundation

/// Ensures only one copy of the app runs at a time.
///
/// Two instances both hide the pointer and both draw a cursor, and because the
/// hide is reference counted at the window-server level, quitting one leaves
/// the pointer hidden by the other -- which looks exactly like the app failing
/// to clean up after itself.
///
/// A file lock rather than a bundle-identifier check, because the app is also
/// run straight from the command line during development and testing, where
/// there is no bundle to compare against. The lock is released by the kernel
/// when the process exits, including on a crash.
enum SingleInstance {
    private static var descriptor: Int32 = -1

    static func acquire() -> Bool {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first
        guard let directory = support?.appendingPathComponent("CatCursor") else { return true }
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)

        let path = directory.appendingPathComponent("instance.lock").path
        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        // If the lock file itself is unusable, do not block startup over it.
        guard fd >= 0 else { return true }

        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return false
        }
        descriptor = fd
        return true
    }
}
