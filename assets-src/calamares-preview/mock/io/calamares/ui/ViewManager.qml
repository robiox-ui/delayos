pragma Singleton
import QtQuick
QtObject {
    property int currentStepIndex: mockStep
    property bool backEnabled: true
    property bool nextEnabled: true
    property bool backAndNextVisible: currentStepIndex !== 7
    function next() { console.log("next") }
    function back() { console.log("back") }
    function quit() { console.log("quit") }
}