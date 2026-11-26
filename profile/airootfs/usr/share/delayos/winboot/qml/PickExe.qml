import QtQuick
import QtQuick.Dialogs

// File picker for "Windows 게임 추가" (loaded only when "찾아보기" is pressed).
FileDialog {
    signal picked(string url)
    title: "Windows 드라이브에서 게임 실행 파일 선택"
    nameFilters: ["Windows 프로그램 (*.exe)", "모든 파일 (*)"]
    onAccepted: picked(selectedFile.toString())
}
