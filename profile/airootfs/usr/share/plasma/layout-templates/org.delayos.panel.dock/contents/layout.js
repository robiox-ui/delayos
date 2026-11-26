// DelayOS floating dock (ui-spec 3.2): centred, fit to content (506 x 47 with 9 items),
// 17 px above the bottom edge, radius 14, glass. It never reserves space and never
// "unfloats": windows go below it (maximised windows reach the bottom edge under it).
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

var dockPanel = new Panel("org.kde.panel");
dockPanel.location = "bottom";
dockPanel.height = 47;
dockPanel.floating = true;
dockPanel.lengthMode = "fit";
dockPanel.alignment = "center";
dockPanel.hiding = "windowsgobelow";
try { dockPanel.opacity = "translucent"; } catch (e) {}

var dock = dockPanel.addWidget("org.delayos.dock");
dock.currentConfigGroup = ["General"];
dock.writeConfig("mode", "dock");
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
// The Start popup (org.delayos.start) lives in the top bar with the other DelayOS popups.
