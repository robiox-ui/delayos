// TEMUOS top bar (ui-spec 3.1): full width, 28 px, glass, no margin.
//  [logo | app name ............] [tray icons] [게이밍] [status cluster + date/time]
// plus the zero-width TEMUOS popups (Start, command bar, Control Center, calendar, clipboard, Win+X, All apps).
var known = knownWidgetTypes;
function has(id) { return known.indexOf(id) >= 0; }

var top = new Panel("org.kde.panel");
top.location = "top";
top.height = 28;
top.floating = false;
top.lengthMode = "fill";
top.hiding = "none";
try { top.opacity = "translucent"; } catch (e) {}

top.addWidget("org.temuos.topbar");

// StatusNotifier icons only (Steam etc.); every Plasma tray applet is replaced by TEMUOS ones
var tray = top.addWidget("org.kde.plasma.systemtray");
// Plasma 6: the tray keeps its own item list in its [General] group
tray.currentConfigGroup = ["General"];
tray.writeConfig("knownItems", known);     // never auto-add a tray plasmoid later
tray.writeConfig("extraItems", []);        // load none of them (TEMUOS has its own status area)
tray.writeConfig("showAllItems", true);    // no expander arrow
tray.reloadConfig();
top.addWidget("org.temuos.gamingtoggle");
var status = top.addWidget("org.temuos.status");
status.currentConfigGroup = ["General"];
status.writeConfig("mode", "topbar");

// TEMUOS popups (shell-popups stream): headless 0 px plasmoids that draw their own glass windows.
// Meta alone opens Start (it provides org.kde.plasma.launchermenu).
var popups = { "org.temuos.start": "", "org.temuos.commandbar": "Meta+Space", "org.temuos.controlcenter": "Meta+A",
               "org.temuos.calendar": "", "org.temuos.clipboard": "Meta+V", "org.temuos.winx": "Meta+X",
               "org.temuos.allapps": "" };
for (var pid in popups) {
    if (!has(pid)) continue;
    var pw = top.addWidget(pid);
    if (popups[pid]) pw.globalShortcut = popups[pid];
}