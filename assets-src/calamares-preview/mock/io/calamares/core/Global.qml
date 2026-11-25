pragma Singleton
import QtQuick
QtObject {
    property var store: ({ "username": "alex" })
    function value(k) { return store[k] }
    function contains(k) { return store[k] !== undefined }
    function insert(k, v) { store[k] = v }
}