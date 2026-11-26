// DelayOS "Taskbar" look (ui-spec 3.4): no top bar, one full-width 43 px glass bar at the bottom.
//  [            Start Search TaskView pinned apps (centred on screen)        ] [tray] [⚡ ☼ wifi vol bat] [clock] [bell]
var known = knownWidgetTypes;
function has(id) { return known.indexOf(id) >= 0; }
// the user's pins survive a dock <-> taskbar switch (delay-shell-layout saves them in ~/.config/delayosrc)
function savedPins() {
    try {
        var c = ConfigFile("delayosrc", "Dock");
        var s = c.readEntry("launchers");
        if (s && String(s).length) return String(s).split(",");
    } catch (e) {}
    return null;
}
function pins() {
    var browser = applicationExists("google-chrome.desktop") || applicationExists("google-chrome")
        ? "applications:google-chrome.desktop"
        : (applicationExists("firefox.desktop") || applicationExists("firefox") ? "applications:firefox.desktop" : "");
    var l = ["applications:org.delayos.Files.desktop", "applications:org.delayos.Notepad.desktop",
             "applications:org.delayos.Calculator.desktop", "applications:org.delayos.TaskManager.desktop",
             "applications:org.delayos.Settings.desktop"];
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

var dock = bar.addWidget("org.delayos.dock");
dock.currentConfigGroup = ["General"];
dock.writeConfig("mode", "taskbar");
dock.writeConfig("launchers", savedPins() || pins());
dock.writeConfig("defaultLaunchers", pins());
// bar menu options chosen in the other layout (delay-shell-layout saves them next to the pins)
try {
    var saved = ConfigFile("delayosrc", "Dock");
    ["showTaskView", "searchMode", "locked"].forEach(function (k) {
        var v = saved.readEntry(k);
        if (v !== undefined && v !== null && String(v).length) dock.writeConfig(k, String(v));
    });
} catch (e) {}

// DelayOS popups (shell-popups stream): headless plasmoids that draw their own glass windows.
// Meta alone opens Start (it provides org.kde.plasma.launchermenu). The panel still gives each of
// them a small slot, so they sit right after the filling left applet, in the empty middle of the bar.
var popups = { "org.delayos.start": "", "org.delayos.commandbar": "Meta+Space", "org.delayos.controlcenter": "Meta+A",
               "org.delayos.calendar": "", "org.delayos.clipboard": "Meta+V", "org.delayos.winx": "Meta+X",
               "org.delayos.allapps": "" };
for (var pid in popups) {
    if (!has(pid)) continue;
    var pw = bar.addWidget(pid);
    if (popups[pid]) pw.globalShortcut = popups[pid];
}

var tray = bar.addWidget("org.kde.plasma.systemtray");
// Plasma 6: the tray keeps its own item list in its [General] group
tray.currentConfigGroup = ["General"];
tray.writeConfig("knownItems", known);     // never auto-add a tray plasmoid later
tray.writeConfig("extraItems", []);        // load none of them (DelayOS has its own status area)
tray.writeConfig("showAllItems", true);    // no expander arrow
tray.reloadConfig();
if (has("org.delayos.gamingtoggle")) bar.addWidget("org.delayos.gamingtoggle");   // one-click Gaming mode, always visible
var status = bar.addWidget("org.delayos.status");
status.currentConfigGroup = ["General"];
status.writeConfig("mode", "taskbar");
