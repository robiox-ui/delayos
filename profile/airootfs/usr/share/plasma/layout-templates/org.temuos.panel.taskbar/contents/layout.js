// TEMUOS "Taskbar" look (ui-spec 3.4): no top bar, one full-width 43 px glass bar at the bottom.
//  [            Start Search TaskView pinned apps (centred on screen)        ] [tray] [⚡ ☼ wifi vol bat] [clock] [bell]
var known = knownWidgetTypes;
function has(id) { return known.indexOf(id) >= 0; }
// the user's pins survive a dock <-> taskbar switch (temu-shell-layout saves them in ~/.config/temuosrc)
function savedPins() {
    try {
        var c = ConfigFile("temuosrc", "Dock");
        var s = c.readEntry("launchers");
        if (s && String(s).length) return String(s).split(",");
    } catch (e) {}
    return null;
}
function pins() {
    var browser = applicationExists("google-chrome.desktop") || applicationExists("google-chrome")
        ? "applications:google-chrome.desktop"
        : (applicationExists("firefox.desktop") || applicationExists("firefox") ? "applications:firefox.desktop" : "");
    var l = ["applications:org.temuos.Files.desktop", "applications:org.temuos.Notepad.desktop",
             "applications:org.temuos.Calculator.desktop", "applications:org.temuos.TaskManager.desktop",
             "applications:org.temuos.Settings.desktop"];
    if (browser) l.push(browser);
    return l;
}

var bar = new Panel("org.kde.panel");
bar.location = "bottom";
bar.height = 43;
bar.floating = false;
bar.lengthMode = "fill";
bar.hiding = "none";
try { bar.opacity = "translucent"; } catch (e) {}

var dock = bar.addWidget("org.temuos.dock");
dock.currentConfigGroup = ["General"];
dock.writeConfig("mode", "taskbar");
dock.writeConfig("launchers", savedPins() || pins());
dock.writeConfig("defaultLaunchers", pins());

var tray = bar.addWidget("org.kde.plasma.systemtray");
// Plasma 6: the tray keeps its own item list in its [General] group
tray.currentConfigGroup = ["General"];
tray.writeConfig("knownItems", known);     // never auto-add a tray plasmoid later
tray.writeConfig("extraItems", []);        // load none of them (TEMUOS has its own status area)
tray.writeConfig("showAllItems", true);    // no expander arrow
tray.reloadConfig();
var status = bar.addWidget("org.temuos.status");
status.currentConfigGroup = ["General"];
status.writeConfig("mode", "taskbar");

// TEMUOS popups (shell-popups stream): headless 0 px plasmoids that draw their own glass windows.
// Meta alone opens Start (it provides org.kde.plasma.launchermenu).
var popups = { "org.temuos.start": "", "org.temuos.commandbar": "Meta+Space", "org.temuos.controlcenter": "Meta+A",
               "org.temuos.calendar": "", "org.temuos.clipboard": "Meta+V", "org.temuos.winx": "Meta+X",
               "org.temuos.allapps": "" };
for (var pid in popups) {
    if (!has(pid)) continue;
    var pw = bar.addWidget(pid);
    if (popups[pid]) pw.globalShortcut = popups[pid];
}