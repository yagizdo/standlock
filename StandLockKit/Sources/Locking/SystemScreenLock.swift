import Darwin
import os

public enum SystemScreenLock {
    @MainActor public static func request() -> Bool {
        guard let lockImmediately else {
            logger.error("The macOS immediate screen lock function is unavailable")
            return false
        }
        lockImmediately()
        return true
    }

    private static let logger = Logger(subsystem: "com.yagizdokumaci.standlock", category: "ScreenLock")

    // Resolve the private login.framework entry point at runtime. Immediate locking
    // uses the native login window independently of the user's display sleep settings.
    @MainActor private static let lockImmediately: (@convention(c) () -> Void)? = {
        guard let framework = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY) else {
            return nil
        }
        guard let symbol = dlsym(framework, "SACLockScreenImmediate") else {
            dlclose(framework)
            return nil
        }
        return unsafeBitCast(symbol, to: (@convention(c) () -> Void).self)
    }()
}
