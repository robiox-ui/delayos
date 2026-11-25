import QtQuick
import QtCore
import QtQuick.Dialogs

// Native (portal) image picker; emits a local path.
FileDialog {
    signal picked(string path)
    title: "사진 선택"
    nameFilters: ["이미지 (*.png *.jpg *.jpeg *.webp *.avif *.jxl *.svg)"]
    currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    onAccepted: picked(decodeURIComponent(selectedFile.toString().replace("file://", "")))
}
