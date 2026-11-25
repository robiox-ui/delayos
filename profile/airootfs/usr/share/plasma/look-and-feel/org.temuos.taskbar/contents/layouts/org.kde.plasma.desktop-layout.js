// TEMUOS_LINUX "Taskbar" layout: one full-width bottom bar, no top bar (Windows 11 style)
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/TemuCurrent/");
}

var bar = new Panel;
bar.location = "bottom";
bar.height = Math.round(gridUnit * 2.4);
bar.floating = false;
bar.lengthMode = "fill";

bar.addWidget("org.kde.plasma.panelspacer");
var start = bar.addWidget("org.kde.plasma.kickoff");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "temuos-logo");

var tasks = bar.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:temu-search.desktop",
    "applications:temu-taskview.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:steam.desktop",
    "applications:firefox.desktop",
    "applications:systemsettings.desktop"
].join(","));
tasks.writeConfig("middleClickAction", "Close");

bar.addWidget("org.kde.plasma.panelspacer");
try { bar.addWidget("org.temuos.gamingtoggle"); } catch (e) {}
bar.addWidget("org.kde.plasma.systemtray");
var clock = bar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BelowTime");
clock.writeConfig("dateFormat", "shortDate");
