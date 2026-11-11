/// The `/bin/sh` arguments that reopen the app once the current process has exited.
///
/// The new process starts only after the old one is gone, so it reads what the old one wrote
/// on `willTerminate`. A reset deletes the defaults domain in that same gap: nothing of the old
/// process can write after it, so no key comes back.
public enum RelaunchScript {
    public static func arguments(bundlePath: String, pid: Int32, wipingDefaultsDomain domain: String?) -> [String] {
        [
            "-c",
            #"while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.2; done; "#
                + #"if [ -n "$2" ]; then /usr/bin/defaults delete "$2"; fi; /usr/bin/open -n "$0""#,
            bundlePath,
            String(pid),
            domain ?? "",
        ]
    }
}
