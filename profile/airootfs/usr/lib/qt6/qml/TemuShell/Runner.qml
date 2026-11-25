import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Fire-and-forget command runner (no polling; the source is dropped as soon as it finishes).
P5Support.DataSource {
    id: ds
    engine: "executable"
    connectedSources: []
    signal finished(string cmd, int exitCode, string stdout)
    onNewData: (source, data) => {
        disconnectSource(source)
        finished(source, data["exit code"] || 0, data["stdout"] || "")
    }
    function exec(cmd) {
        // detach so that long-running apps do not keep the source busy
        connectSource(cmd)
    }
    // shell-quote one argument
    function q(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }
}
