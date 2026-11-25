import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Fire-and-forget / one-shot shell command runner for shell plasmoids.
//   Exec { id: sh; onFinished: (cmd, out, code) => ... }   sh.run("temu-gamemode status")
P5Support.DataSource {
    id: src
    engine: "executable"
    connectedSources: []
    signal finished(string cmd, string stdout, int exitCode)
    property int _seq: 0
    onNewData: (source, data) => {
        disconnectSource(source)
        // strip the uniquifying comment again
        var cmd = source.replace(/ #\d+$/, "")
        src.finished(cmd, data["stdout"] || "", data["exit code"] || 0)
    }
    function run(cmd) {
        _seq = (_seq + 1) % 100000
        connectSource(cmd + " #" + _seq)
    }
}
