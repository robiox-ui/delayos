// DelayOS top bar (ui-spec 3.1): full width, 28 px, glass, no margin.
//  [logo | app name ............] [tray icons] [게이밍] [status cluster + date/time]
// plus the zero-width DelayOS popups (Start, command bar, Control Center, calendar, clipboard, Win+X, All apps).
var known = knownWidgetTypes;
function has(id) { return known.indexOf(id) >= 0; }

var top = new Panel("org.kde.panel");
top.location = "top";
top.height = 28;
top.floating = false;
top.lengthMode = "fill";
top.hiding = "none";
try { top.opacity = "translucent"; } catch (e) {}

top.addWidget("org.delayos.topbar");

// DelayOS popups (shell-popups stream): headless plasmoids that draw their own glass windows.
// Meta alone opens Start (it provides org.kde.plasma.launchermenu). The panel still gives each of
// them a small slot, so they sit right after the filling left applet, in the empty middle of the bar.
var popups = { "org.delayos.start": "", "org.delayos.commandbar": "Meta+Space", "org.delayos.controlcenter": "Meta+A",
               "org.delayos.calendar": "", "org.delayos.clipboard": "Meta+V", "org.delayos.winx": "Meta+X",
               "org.delayos.allapps": "" };
for (var pid in popups) {
    if (!has(pid)) continue;
    var pw = top.addWidget(pid);
    if (popups[pid]) pw.globalShortcut = popups[pid];
}

// StatusNotifier icons only (Steam etc.); every Plasma tray applet is replaced by DelayOS ones
var tray = top.addWidget("org.kde.plasma.systemtray");
// Plasma 6: the tray keeps its own item list in its [General] group
tray.currentConfigGroup = ["General"];
tray.writeConfig("knownItems", known);     // never auto-add a tray plasmoid later
tray.writeConfig("extraItems", []);        // load none of them (DelayOS has its own status area)
tray.writeConfig("showAllItems", true);    // no expander arrow
tray.reloadConfig();
top.addWidget("org.delayos.gamingtoggle");
var status = top.addWidget("org.delayos.status");
status.currentConfigGroup = ["General"];
status.writeConfig("mode", "topbar");
