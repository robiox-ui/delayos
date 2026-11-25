import QtQuick
import QtQuick.Layouts
import TemuUI
import TemuSys

// 앱 › 기본 앱
SPage {
    id: pg
    property var d: ({ browser: "", browsers: [] })
    Component.onCompleted: win.call("pkgs.defaults", [], function(r) { if (r && !r.error) pg.d = r })
    function bidx() { for (var i = 0; i < d.browsers.length; i++) if (d.browsers[i].id === d.browser) return i; return -1 }

    SRow {
        icon: "g:web"; title: "웹 브라우저"
        subtitle: pg.d.browsers.length ? "링크와 웹 페이지를 여는 앱" : "설치된 웹 브라우저가 없습니다. TEMUOS Store에서 설치하세요."
        SDropdown {
            implicitWidth: 200
            model: pg.d.browsers.map(function(b) { return b.name })
            currentIndex: pg.bidx()
            displayText: currentIndex >= 0 ? model[currentIndex] : "선택 안 됨"
            onActivated: (i) => win.call("pkgs.set_browser", [pg.d.browsers[i].id], function(r) { if (r.ok) win.toast("기본 브라우저를 바꿨습니다") })
        }
    }
    SRow { icon: "starred-symbolic"; title: "파일 형식별 기본 앱"; subtitle: "이메일, 음악, 동영상, 사진, 문서 등"; chevron: true; onClicked: sys.detach(["kcmshell6", "kcm_componentchooser"]) }
    SRow { icon: "window-duplicate"; title: "Windows 프로그램 (.exe, .msi)"; subtitle: "Windows Engine으로 엽니다"; chevron: true; onClicked: pg.navigate("appsupport#windows") }
    SRow { icon: "g:apk"; title: "Android 앱 (.apk)"; subtitle: "Android 앱 지원으로 설치합니다"; chevron: true; onClicked: pg.navigate("appsupport#android") }
}
