import QtQuick
import TemuUI

// 설정: default start page and live update speed.
Flickable {
    contentHeight: col.height + 32
    clip: true
    Column {
        id: col
        x: 20; y: 14
        width: parent.width - 40
        spacing: 4
        Text { text: "설정"; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.text1; bottomPadding: 8 }
        TRow {
            iconName: "home"; title: "기본 시작 페이지"; subtitle: "작업 관리자를 열 때 처음 보이는 페이지"
            TDropdown {
                readonly property var keys: ["processes", "performance", "apphistory", "startup", "users", "details", "services"]
                model: ["프로세스", "성능", "앱 기록", "시작 앱", "사용자", "세부 정보", "서비스"]
                currentIndex: Math.max(0, keys.indexOf(backend.getStartPage()))
                onActivated: (i) => backend.setStartPage(keys[i])
            }
        }
        TRow {
            iconName: "refresh"; title: "실시간 업데이트 속도"; subtitle: "창이 보일 때만 새로 고쳐요"
            TDropdown {
                readonly property var vals: [500, 1000, 4000, 0]
                model: ["높음", "보통", "낮음", "일시 중지"]
                currentIndex: Math.max(0, vals.indexOf(backend.interval))
                onActivated: (i) => backend.interval = vals[i]
            }
        }
    }
}
