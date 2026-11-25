import QtQuick

// Copies text to the system clipboard (Start / Command bar answers: "Enter copies").
TextEdit {
    id: te
    visible: false
    function copyText(t) {
        te.text = t
        te.selectAll()
        te.copy()
        te.text = ""
    }
}
