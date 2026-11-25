import QtQuick
import QtQuick.Layouts
import DelayUI
import DelaySys

// 앱
SPage {
    id: pg
    SRow { icon: "view-list-icons"; title: "설치된 앱"; subtitle: "앱 제거, 크기 및 출처 확인"; chevron: true; onClicked: pg.navigate("installed") }
    SRow { icon: "starred-symbolic"; title: "기본 앱"; subtitle: "웹 브라우저 및 파일 형식별 기본 앱"; chevron: true; onClicked: pg.navigate("defaultapps") }
    SRow { icon: "system-run"; title: "시작 프로그램"; subtitle: "로그인할 때 자동으로 시작되는 앱"; chevron: true; onClicked: pg.navigate("startup") }
    SRow { icon: "input-keyboard"; title: "키 매핑"; subtitle: "키보드와 마우스로 Android 게임 플레이"; chevron: true; onClicked: pg.navigate("keymapping") }
    SHeader { text: "앱 더 받기" }
    SRow { appIcon: "delayos-store"; title: "DelayOS Store"; subtitle: "Flathub와 공식 저장소의 앱을 찾아 설치합니다"; chevron: true; onClicked: sys.detach(["delay-store"]) }
    SRow { icon: "window-duplicate"; title: "앱 지원"; subtitle: "Windows 프로그램, Android 앱 실행"; chevron: true; onClicked: pg.navigate("appsupport") }
}
