// DelayOS "Taskbar" layout (ui-spec 2 + 3.4).
// Panels come from the layout templates so that /usr/local/bin/delay-shell-layout can rebuild them live.

// ---- Desktop: Tide wallpaper, icons that stay where you put them ----
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", fileExists("/usr/share/wallpapers/DelayTide/metadata.json")
                  ? "file:///usr/share/wallpapers/DelayTide/" : "file:///usr/share/wallpapers/DelayCurrent/");
    d.writeConfig("FillMode", 2);               // scaled and cropped
    d.currentConfigGroup = ["General"];
    d.writeConfig("arrangement", 0);            // columns, top-left first
    d.writeConfig("alignment", 0);
    d.writeConfig("iconSize", 3);               // 48 px
    d.writeConfig("labelWidth", 1);
    d.writeConfig("textLines", 2);
    d.writeConfig("previews", true);
    d.writeConfig("sortMode", -1);              // manual: positions persist
    d.writeConfig("toolTips", false);
    d.writeConfig("selectionMarkers", false);
    d.writeConfig("popups", false);
    // right-click on the empty desktop: the DelayOS menu (containment action org.delayos.desktopmenu).
    // A layout script cannot choose the mouse actions; they are the root group [ActionPlugins][0] of
    // plasma-org.kde.plasma.desktop-appletsrc, which ships in /etc/skel and is written for existing or
    // reset layouts by /etc/xdg/plasma-workspace/env/delay-desktop-menu.sh.
}

// ---- Full-width taskbar ----
loadTemplate("org.delayos.panel.taskbar");
