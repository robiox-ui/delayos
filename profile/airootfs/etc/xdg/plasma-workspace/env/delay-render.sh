# DelayOS render profile, sourced by startplasma before KWin and plasmashell start.
# /run/delay/render is written at boot by delay-render-detect.service.
# software = no usable GPU (llvmpipe): a config layer above /etc/xdg turns off what the CPU cannot
# draw smoothly (blur, background contrast, rounded-corner shader, animations). The user's own
# ~/.config still wins, nothing is written to disk, and with a GPU this file does nothing.
if [ "$(cat /run/delay/render 2>/dev/null)" = software ]; then
    export DELAY_SOFTWARE_RENDER=1
    export XDG_CONFIG_DIRS="/usr/share/delayos/render-software/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}"
else
    export DELAY_SOFTWARE_RENDER=0
fi
