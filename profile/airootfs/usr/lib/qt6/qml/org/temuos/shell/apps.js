.pragma library
// Helpers shared by the top bar and the dock.

// Windows-Engine (RemoteApp) windows: app id / class starts with "temu-win" (contract with the
// apps stream), or a FreeRDP/WinApps RemoteApp window.
var WIN_RE = /^(temu-?win|org\.temuos\.win|winapps|xfreerdp|wlfreerdp|sdl-freerdp|sdl3-freerdp|freerdp)/i;

function isWindowsApp(appId, launcherUrl) {
    var a = (appId || "") + "";
    var u = (launcherUrl || "") + "";
    if (WIN_RE.test(a)) return true;
    var m = u.match(/([^\/]+)\.desktop$/);
    return m !== null && WIN_RE.test(m[1]);
}

function isSteam(appId) {
    var a = ((appId || "") + "").toLowerCase();
    return a === "steam" || a === "com.valvesoftware.steam" || a === "steamwebhelper";
}

// "11월 24일 (화)"
function koDate(d) {
    var days = ["일", "월", "화", "수", "목", "금", "토"];
    return (d.getMonth() + 1) + "월 " + d.getDate() + "일 (" + days[d.getDay()] + ")";
}
function pad2(n) { return n < 10 ? "0" + n : "" + n; }
function hhmm(d) { return pad2(d.getHours()) + ":" + pad2(d.getMinutes()); }
function isoDate(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()); }
