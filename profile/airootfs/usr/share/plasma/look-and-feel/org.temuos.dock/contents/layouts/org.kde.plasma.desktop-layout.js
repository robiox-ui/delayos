// TEMUOS_LINUX default layout ("Dock and top bar", ui-spec 2 + 3).
// Panels come from the layout templates so that /usr/local/bin/temu-shell-layout can rebuild them live.

// ---- Desktop: Tide wallpaper, icons that stay where you put them ----
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
    var d = allDesktops[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", fileExists("/usr/share/wallpapers/TemuTide/metadata.json")
                  ? "file:///usr/share/wallpapers/TemuTide/" : "file:///usr/share/wallpapers/TemuCurrent/");
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
    // right-click: only the TEMUOS-relevant entries of the desktop context menu
    d.currentConfigGroup = ["ActionPlugins", "0", "RightButton;NoModifier"];
    d.writeConfig("_add panel", false);
    d.writeConfig("_context", true);
    d.writeConfig("_display_settings", true);
    d.writeConfig("_lock_screen", false);
    d.writeConfig("_logout", false);
    d.writeConfig("_open_terminal", false);
    d.writeConfig("_run_command", false);
    d.writeConfig("_sep1", true);
    d.writeConfig("_sep2", false);
    d.writeConfig("_sep3", false);
    d.writeConfig("_wallpaper", false);
    d.writeConfig("add widgets", false);
    d.writeConfig("configure", true);
    d.writeConfig("configure shortcuts", false);
    d.writeConfig("edit mode", false);
    d.writeConfig("manage activities", false);
    d.writeConfig("remove", false);
}

// ---- Top bar + floating dock ----
loadTemplate("org.temuos.panel.topbar");
loadTemplate("org.temuos.panel.dock");
