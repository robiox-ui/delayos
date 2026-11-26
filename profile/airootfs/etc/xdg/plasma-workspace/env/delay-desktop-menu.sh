# DelayOS desktop right-click menu: makes sure the Plasma layout uses it.
# Sourced by startplasma before plasmashell starts. The mouse actions of the desktop are the root
# group [ActionPlugins][0] of plasma-org.kde.plasma.desktop-appletsrc; new users get it from
# /etc/skel. Handled here:
#   - no layout file (it was deleted to reset the layout): start it with the DelayOS mouse
#     actions, Plasma then adds the default layout to it;
#   - a layout from before this update, which still names KDE's menu (org.kde.contextmenu) for
#     the right button: switched once. The marker in ~/.config/delayosrc makes it a one-time
#     change, so whoever picks another mouse action afterwards keeps it;
#   - the plugin cannot be loaded (missing, or built for another libPlasma after an update):
#     KDE's menu is used until it loads again, instead of a desktop without any menu.
_dm_cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
_dm_rc="$_dm_cfg/plasma-org.kde.plasma.desktop-appletsrc"
_dm_so=/usr/lib/qt6/plugins/plasma/containmentactions/org.delayos.desktopmenu.so
_dm_set() {
    kwriteconfig6 --file "$_dm_rc" --group ActionPlugins --group 0 --key 'RightButton;NoModifier' "$1"
}
if [ -e "$_dm_so" ] && ! ldd "$_dm_so" 2>/dev/null | grep -q 'not found'; then
    if [ ! -e "$_dm_rc" ]; then
        mkdir -p "$_dm_cfg" && cp /etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc "$_dm_rc" 2>/dev/null
    elif ! grep -qs '^desktopmenu=1$' "$_dm_cfg/delayosrc"; then
        _dm_set org.delayos.desktopmenu
        kwriteconfig6 --file "$_dm_cfg/delayosrc" --group Migrations --key desktopmenu 1
    fi
elif grep -qs '^RightButton;NoModifier=org.delayos.desktopmenu$' "$_dm_rc"; then
    _dm_set org.kde.contextmenu
    kwriteconfig6 --file "$_dm_cfg/delayosrc" --group Migrations --key desktopmenu --delete
fi
unset -f _dm_set
unset _dm_cfg _dm_rc _dm_so
