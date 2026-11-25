// TEMUOS_LINUX "Dock and top bar" layout
// Top: logo menu | active app name | ... | gaming pill | tray (Control Center) | clock
// Bottom: small floating centred dock (Start, Search, Task View, pinned apps)

// ---- Desktop (icons that stay where you put them, Refresh in right-click) ----
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/TemuCurrent/");
    d.currentConfigGroup = ["General"];
    d.writeConfig("arrangement", 0);
    d.writeConfig("positions", "");
}

// ---- Top bar ----
var top = new Panel;
top.location = "top";
top.height = Math.round(gridUnit * 1.5);
top.floating = false;
top.lengthMode = "fill";
top.hiding = "none";

var logo = top.addWidget("org.kde.plasma.kickoff");
logo.currentConfigGroup = ["General"];
logo.writeConfig("icon", "temuos-logo");
logo.writeConfig("favoritesPortedToKAstats", true);

// Active app name (macOS-style); falls back silently if the applet is missing
try {
    var title = top.addWidget("org.kde.windowtitle");
    title.currentConfigGroup = ["General"];
    title.writeConfig("showIcon", false);
    title.writeConfig("boldFont", false);
    title.writeConfig("filterActivityInfo", true);
    title.writeConfig("placeHolder", "Desktop");
} catch (e) {}

top.addWidget("org.kde.plasma.panelspacer");

// One-click Gaming mode pill
try { top.addWidget("org.temuos.gamingtoggle"); } catch (e) {}

var tray = top.addWidget("org.kde.plasma.systemtray");

var clock = top.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("use24hFormat", 2);

// ---- Floating dock ----
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 2.6);
dock.floating = true;
dock.lengthMode = "fit";       // dock only as wide as its icons
dock.alignment = "center";
dock.hiding = "none";          // Settings > Auto-hide switches this to "autohide"

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:temu-start.desktop",
    "applications:temu-search.desktop",
    "applications:temu-taskview.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:org.kde.kwrite.desktop",
    "applications:org.kde.kcalc.desktop",
    "applications:org.kde.plasma-systemmonitor.desktop",
    "applications:systemsettings.desktop",
    "applications:steam.desktop",
    "applications:firefox.desktop"
].join(","));
tasks.writeConfig("showOnlyCurrentDesktop", false);
tasks.writeConfig("groupingStrategy", 1);
tasks.writeConfig("middleClickAction", "Close");
tasks.writeConfig("indicateAudioStreams", true);
tasks.writeConfig("iconSpacing", 1);
tasks.writeConfig("maxStripes", 1);
