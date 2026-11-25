.pragma library
// Settings information architecture: navigation, pages, search index (§8).

var nav = [
    { id: "system", label: "시스템" },
    { id: "bluetooth", label: "Bluetooth 및 장치" },
    { id: "network", label: "네트워크 및 인터넷" },
    { id: "personalisation", label: "개인 설정" },
    { id: "apps", label: "앱" },
    { id: "accounts", label: "계정" },
    { id: "time", label: "시간 및 언어" },
    { id: "appsupport", label: "앱 지원" },
    { id: "update", label: "업데이트 및 드라이버" }
]

// id -> { file, title, parent }
var pages = {
    system:          { file: "System", title: "시스템" },
    display:         { file: "Display", title: "디스플레이", parent: "system" },
    sound:           { file: "Sound", title: "소리", parent: "system" },
    notifications:   { file: "Notifications", title: "알림", parent: "system" },
    power:           { file: "Power", title: "전원 및 배터리", parent: "system" },
    storage:         { file: "Storage", title: "저장소", parent: "system" },
    about:           { file: "About", title: "정보", parent: "system" },
    bluetooth:       { file: "Bluetooth", title: "Bluetooth 및 장치" },
    mouse:           { file: "Mouse", title: "마우스 및 터치패드", parent: "bluetooth" },
    network:         { file: "Network", title: "네트워크 및 인터넷" },
    personalisation: { file: "Personalisation", title: "개인 설정" },
    background:      { file: "Background", title: "배경", parent: "personalisation" },
    colours:         { file: "Colours", title: "색", parent: "personalisation" },
    apps:            { file: "Apps", title: "앱" },
    installed:       { file: "Installed", title: "설치된 앱", parent: "apps" },
    defaultapps:     { file: "DefaultApps", title: "기본 앱", parent: "apps" },
    startup:         { file: "Startup", title: "시작 프로그램", parent: "apps" },
    keymapping:      { file: "KeyMapping", title: "키 매핑", parent: "apps" },
    accounts:        { file: "Accounts", title: "계정" },
    time:            { file: "Time", title: "시간 및 언어" },
    appsupport:      { file: "AppSupport", title: "앱 지원" },
    update:          { file: "Update", title: "업데이트 및 드라이버" }
}

// command-line / desktop-action aliases (temu-settings <alias>)
var alias = {
    "personalization": "personalisation", "wallpaper": "background", "colors": "colours", "theme": "colours",
    "dock": "personalisation", "taskbar": "personalisation", "touchpad": "mouse", "wifi": "network",
    "drivers": "update", "updates": "update", "language": "time", "keymap": "keymapping", "gamecontrols": "keymapping",
    "battery": "power", "users": "accounts", "windows": "appsupport", "android": "appsupport", "anticheat": "appsupport"
}

function crumbOf(id) {
    var p = pages[id]
    if (!p) return ""
    return p.parent ? pages[p.parent].title + " › " + p.title : p.title
}
function iconOf(id) { var p = pages[id]; return p && p.parent ? p.parent : id }

// [title, page, key, keywords]; order = result order (pages first, like the reference)
var rows = [
    ["마우스 및 터치패드", "mouse", "", "mouse touchpad 마우스 터치패드 포인터"],
    ["키 매핑", "keymapping", "", "key mapping mouse keyboard game 게임 키보드 마우스 조작"],
    ["Bluetooth", "bluetooth", "bt-power", "bluetooth 블루투스 mouse headset 이어폰 장치"],
    ["마우스 포인터 속도", "mouse", "m-speed", "mouse pointer speed 커서"],
    ["기본 마우스 버튼", "mouse", "m-primary", "primary mouse button left right 왼손 오른손"],
    ["스크롤 속도", "mouse", "m-scroll", "scrolling speed wheel mouse 휠"],
    ["스크롤 방향 반대로", "mouse", "m-natural", "reverse scrolling direction natural mouse"],
    ["탭하여 클릭", "mouse", "t-tap", "tap to click touchpad mouse"],
    ["터치패드 스크롤 방향", "mouse", "t-natural", "touchpad scrolling direction mouse"],
    ["터치패드 커서 속도", "mouse", "t-speed", "touchpad cursor speed mouse"],
    ["게임 컨트롤", "keymapping", "gc-enabled", "game controls android mouse keyboard 안드로이드"],
    ["조준용 마우스 속도", "keymapping", "gc-aim", "mouse speed for aiming 에임"],
    ["디스플레이", "display", "", "display screen monitor resolution 화면 모니터 해상도"],
    ["해상도", "display", "d-res", "resolution display 화면"],
    ["배율", "display", "d-scale", "scale zoom hidpi 크기 확대"],
    ["새로 고침 빈도", "display", "d-rate", "refresh rate hz 주사율"],
    ["야간 모드", "display", "d-night", "night light 야간 블루라이트 따뜻"],
    ["밝기", "display", "d-bright", "brightness 밝기"],
    ["소리", "sound", "", "sound audio volume speaker 오디오 볼륨 스피커"],
    ["출력 장치", "sound", "s-out", "output speaker headphones 스피커 헤드폰"],
    ["입력 장치", "sound", "s-in", "input microphone mic 마이크"],
    ["알림", "notifications", "", "notifications 알림"],
    ["방해 금지", "notifications", "n-dnd", "do not disturb dnd 방해"],
    ["전원 및 배터리", "power", "", "power battery sleep 전원 배터리 절전"],
    ["전원 모드", "power", "p-profile", "power mode performance 성능 절전"],
    ["화면 끄기 및 절전", "power", "p-sleep", "screen sleep timeout 절전 화면 끄기"],
    ["저장소", "storage", "", "storage disk space 디스크 용량"],
    ["정보", "about", "", "about system info pc specs 사양 정보 cpu ram"],
    ["PC 이름 바꾸기", "system", "rename", "rename pc hostname 이름"],
    ["Wi-Fi", "network", "wifi", "wifi wireless 무선 네트워크"],
    ["비행기 모드", "network", "airplane", "airplane mode 비행기"],
    ["이더넷", "network", "ethernet", "ethernet wired 유선"],
    ["VPN", "network", "vpn", "vpn"],
    ["배경", "background", "", "background wallpaper 배경 화면 바탕"],
    ["색", "colours", "", "colours colors accent dark light mode 색 강조색 다크 라이트 테마"],
    ["강조색", "colours", "accent", "accent colour color 강조"],
    ["모드 선택", "colours", "mode", "dark light mode 다크 라이트"],
    ["독 및 작업 표시줄", "personalisation", "dock", "dock taskbar top bar 독 작업 표시줄 상단 바"],
    ["독 자동 숨기기", "personalisation", "autohide", "auto-hide dock 자동 숨기기"],
    ["설치된 앱", "installed", "", "installed apps uninstall remove 제거 삭제 앱"],
    ["기본 앱", "defaultapps", "", "default apps browser 기본 브라우저"],
    ["시작 프로그램", "startup", "", "startup autostart 시작"],
    ["계정", "accounts", "", "accounts user password 사용자 암호 비밀번호"],
    ["날짜 및 시간", "time", "tz", "date time timezone 날짜 시간 표준 시간대"],
    ["언어", "time", "lang", "language korean 언어 한국어"],
    ["키보드", "time", "kbd", "keyboard layout input 키보드 입력 한영"],
    ["Windows 앱", "appsupport", "windows", "windows exe wine proton 윈도우"],
    ["Android 앱", "appsupport", "android", "android apk waydroid 안드로이드"],
    ["안티치트", "appsupport", "eac", "anti-cheat eac easy anti cheat 안티치트"],
    ["업데이트 확인", "update", "check", "update upgrade 업데이트"],
    ["드라이버", "update", "drivers", "drivers nvidia amd intel gpu 그래픽 드라이버"]
]

function search(q) {
    q = (q || "").trim().toLowerCase()
    if (!q) return []
    var res = []
    for (var i = 0; i < rows.length; i++) {
        var r = rows[i]
        if (r[0].toLowerCase().indexOf(q) >= 0 || r[3].toLowerCase().indexOf(q) >= 0) {
            var crumb = r[2] === "" ? (pages[r[1]].parent ? crumbOf(r[1]) : pages[r[1]].title) : crumbOf(r[1])
            res.push({ title: r[0], page: r[1], key: r[2], crumb: crumb, icon: iconOf(r[1]) })
        }
        if (res.length >= 12) break
    }
    return res
}

function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

// highlight matched characters in accent
function mark(title, q, color) {
    q = (q || "").trim()
    var i = title.toLowerCase().indexOf(q.toLowerCase())
    if (!q || i < 0) return esc(title)
    return esc(title.substr(0, i)) + "<font color='" + color + "'>" + esc(title.substr(i, q.length)) + "</font>" + esc(title.substr(i + q.length))
}
